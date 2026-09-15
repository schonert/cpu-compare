module Wikidata
  # Pulls CPU specifications from Wikidata and attaches them to CPUs we already
  # hold benchmark results for.
  #
  # Enrichment only — it never creates a CPU. The catalogue is defined by what
  # has been measured; a spec sheet for a part nobody benchmarked would be a row
  # with nothing to show.
  #
  # Coverage is thin and that is expected. Wikidata's "CPU model" class holds a
  # few hundred entities, of which a minority carry clocks, TDP or launch price,
  # against roughly 2,300 distinct processors in the Blender feed. Most of the
  # catalogue therefore has scores and an empty spec sheet, which the UI says
  # plainly rather than padding with dashes.
  class SpecImporter
    # P-numbers are opaque, so the ones the query uses are named here.
    PROPERTIES = {
      "P1141" => "number of processor cores",
      "P7443" => "number of threads",
      "P2107" => "thermal design power",
      "P1547" => "CPU socket",
      "P4139" => "lithography",
      "P2149" => "clock speed",
      "P2284" => "price",
      "P577" => "publication date"
    }.freeze

    # Clock speeds are stored with a unit item rather than a plain number, so
    # GHz values have to be scaled rather than read literally.
    GHZ = "Q80492".freeze
    MHZ = "Q3894832".freeze
    USD = "Q4917".freeze

    QUERY = <<~SPARQL.freeze
      SELECT ?cpu ?cpuLabel ?cores ?threads ?tdp ?socketLabel ?litho ?released
             ?clock ?clockUnit ?price ?priceUnit
      WHERE {
        ?cpu wdt:P31/wdt:P279* wd:Q122967152 .
        OPTIONAL { ?cpu wdt:P1141 ?cores }
        OPTIONAL { ?cpu wdt:P7443 ?threads }
        OPTIONAL { ?cpu wdt:P2107 ?tdp }
        OPTIONAL { ?cpu wdt:P1547 ?socket }
        OPTIONAL { ?cpu wdt:P4139 ?litho }
        OPTIONAL { ?cpu wdt:P577 ?released }
        OPTIONAL {
          ?cpu p:P2149/psv:P2149 ?clockValue .
          ?clockValue wikibase:quantityAmount ?clock ; wikibase:quantityUnit ?clockUnit .
        }
        OPTIONAL {
          ?cpu p:P2284/psv:P2284 ?priceValue .
          ?priceValue wikibase:quantityAmount ?price ; wikibase:quantityUnit ?priceUnit .
        }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en" }
      }
    SPARQL

    def self.call(...) = new(...).call

    def initialize(client: Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call
      run = IngestRun.create!(source_key: Source::WIKIDATA, kind: IngestRun::WIKIDATA_SPECS,
                             status: IngestRun::RUNNING, started_at: Time.current,
                             snapshot_url: Client::ENDPOINT)

      source = Source[Source::WIKIDATA]
      writer = Cpus::SpecWriter.new(source)
      retrieved_at = Time.current

      bindings = @client.select(QUERY)
      # Wikidata returns one row per combination of optional values, so a CPU
      # with two sourced clock statements arrives twice. Fold them together and
      # keep the first non-nil for each field.
      by_qid = bindings.group_by { |b| qid(b.dig("cpu", "value")) }

      matched = 0
      written = 0

      by_qid.each do |qid, rows|
        label = rows.first.dig("cpuLabel", "value")
        cpu = find_cpu(label, qid)
        next if cpu.nil?

        matched += 1
        cpu.update_column(:wikidata_qid, qid) if cpu.wikidata_qid != qid
        written += write_specs(writer, cpu, rows, qid, retrieved_at)
      end

      run.succeed!(
        records_seen: by_qid.size,
        specs_written: written,
        details: {
          "entities_returned" => by_qid.size,
          "matched_to_catalogue" => matched,
          "cpus_with_specs" => Cpu.joins(:cpu_specs).distinct.count,
          "catalogue_size" => Cpu.count
        }
      )
      run
    rescue StandardError => e
      run&.fail!(e.message)
      raise
    end

    private

    def qid(uri) = uri.to_s.split("/").last

    # Wikidata labels parts the way the vendors do ("AMD Ryzen 9 5950X"), which
    # is the same form the normaliser produces, so an exact name match is
    # usually enough. Falls back to the alias table for the rest.
    def find_cpu(label, qid)
      return if label.blank?

      Cpu.find_by(wikidata_qid: qid) ||
        Cpu.find_by(name: label) ||
        Cpu.find_by(name: Cpus::NameNormalizer.call(label).name) ||
        CpuAlias.find_by(normalized_name: label)&.cpu
    end

    def write_specs(writer, cpu, rows, qid, retrieved_at)
      url = "https://www.wikidata.org/wiki/#{qid}"
      written = 0

      simple = {
        "cores" => value_of(rows, "cores")&.to_i,
        "threads" => value_of(rows, "threads")&.to_i,
        "tdp_watts" => value_of(rows, "tdp")&.to_f,
        "socket" => value_of(rows, "socketLabel"),
        "lithography_nm" => value_of(rows, "litho")&.to_f
      }
      units = { "tdp_watts" => "W", "lithography_nm" => "nm" }

      simple.each do |spec_key, value|
        next if value.blank? || value == 0
        written += writer.write(cpu, spec_key: spec_key, value: value,
                                     unit: units[spec_key], statement_url: url,
                                     retrieved_at: retrieved_at)
      end

      if (clock = clock_mhz(rows))
        written += writer.write(cpu, spec_key: "base_clock_mhz", value: clock,
                                     unit: "MHz", statement_url: url, retrieved_at: retrieved_at)
      end

      if (price = usd_price(rows))
        written += writer.write(cpu, spec_key: "launch_price_usd", value: price,
                                     unit: "USD", statement_url: url, retrieved_at: retrieved_at)
      end

      if (released = date_of(rows, "released"))
        written += writer.write(cpu, spec_key: "released_on", value: released,
                                     statement_url: url, retrieved_at: retrieved_at)
      end

      written
    end

    def value_of(rows, key)
      rows.filter_map { |r| r.dig(key, "value").presence }.first
    end

    def date_of(rows, key)
      raw = value_of(rows, key)
      return if raw.blank?

      Date.parse(raw)
    rescue Date::Error
      nil
    end

    # Clocks come with a unit item. GHz is scaled to MHz; anything else is
    # skipped rather than guessed at.
    def clock_mhz(rows)
      row = rows.find { |r| r.dig("clock", "value").present? }
      return if row.nil?

      amount = row.dig("clock", "value").to_f
      case qid(row.dig("clockUnit", "value"))
      when GHZ then (amount * 1000).round
      when MHZ then amount.round
      end
    end

    # Only US dollars are taken. Converting other currencies would invent a
    # figure and an exchange-rate date nobody sourced.
    def usd_price(rows)
      row = rows.find { |r| r.dig("price", "value").present? }
      return if row.nil? || qid(row.dig("priceUnit", "value")) != USD

      row.dig("price", "value").to_f
    end
  end
end
