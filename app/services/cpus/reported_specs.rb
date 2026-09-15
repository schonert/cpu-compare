module Cpus
  # Reads core and thread counts back out of the benchmark submissions.
  #
  # Every Blender run records the machine it ran on, so the feed already knows
  # how many cores and threads each processor has — 2,158 of them, against the
  # few dozen Wikidata covers. This is the difference between a spec sheet that
  # is empty for 94% of the catalogue and one that is filled in for nearly all
  # of it.
  #
  # The figure is the **mode**: the most commonly reported value across a
  # processor's runs. Same reasoning as the median for scores — a public feed
  # contains VMs and restricted containers that under-report, and the mode
  # shrugs them off. The Ryzen 9 5950X is reported as 16 cores 28,563 times and
  # as 8 cores 238 times; the mode is right and the mean would not be.
  #
  # How much the machines agreed is stored with the value, so a shaky figure is
  # visible as a shaky figure rather than passing as a vendor specification.
  # These rows rank below Wikidata and the vendor sources, so anything actually
  # stated by a manufacturer wins.
  class ReportedSpecs
    # Below this level of agreement the machines are telling us different
    # things and we publish nothing rather than pick a winner.
    MIN_AGREEMENT = 75.0
    # Too few reports for a mode to mean anything.
    MIN_SAMPLES = 3

    COLUMNS = { system_cores: "cores", system_threads: "threads" }.freeze

    def self.call(...) = new(...).call

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    def call
      run = IngestRun.create!(source_key: Source::BLENDER_REPORTED, kind: IngestRun::REPORTED_SPECS,
                             status: IngestRun::RUNNING, started_at: Time.current)

      writer = SpecWriter.new(Source[Source::BLENDER_REPORTED])
      retrieved_at = Time.current
      written = 0
      skipped = 0

      COLUMNS.each do |column, spec_key|
        modes(column).each do |cpu_id, (value, samples, agreement)|
          if agreement < MIN_AGREEMENT || samples < MIN_SAMPLES
            skipped += 1
            next
          end

          written += writer.write(
            Cpu.find(cpu_id), spec_key: spec_key, value: value,
            sample_count: samples, agreement_percent: agreement.round(1),
            retrieved_at: retrieved_at
          )
        end
      end

      run.succeed!(
        specs_written: written,
        records_skipped: skipped,
        details: {
          "cpus_with_cores" => CpuSpec.for_key("cores").count,
          "cpus_with_threads" => CpuSpec.for_key("threads").count,
          "below_agreement_threshold" => skipped,
          "min_agreement_percent" => MIN_AGREEMENT
        }
      )
      run
    rescue StandardError => e
      run&.fail!(e.message)
      raise
    end

    private

    # One grouped query per column, folded into cpu_id => [mode, samples,
    # agreement]. Only eligible submissions count, which already excludes
    # multi-socket machines — so a core count here is the per-processor figure
    # rather than a whole system's.
    def modes(column)
      counts = BenchmarkSubmission.eligible.where.not(column => nil)
                                 .group(:cpu_id, column).count

      grouped = Hash.new { |hash, key| hash[key] = [] }
      counts.each { |(cpu_id, value), n| grouped[cpu_id] << [value, n] }

      grouped.transform_values do |pairs|
        total = pairs.sum(&:last)
        value, top = pairs.max_by(&:last)
        [value, total, 100.0 * top / total]
      end
    end
  end
end
