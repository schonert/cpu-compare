require "digest"
require "open-uri"
require "zip"

module BlenderOpenData
  # The Open Data snapshot archive.
  #
  # Wraps the published zip — roughly 100 MB compressed around a 1.9 GB JSONL
  # file — and streams it a line at a time so ingest never holds the whole
  # thing in memory or unpacks it to disk.
  #
  # The checksum is what makes a re-run verifiable: the same snapshot ingested
  # twice is recorded as the same input, so "did this change anything?" is a
  # question the run history can answer.
  class Snapshot
    URL = "https://opendata.blender.org/snapshots/opendata-latest.zip".freeze
    DEFAULT_PATH = Rails.root.join("tmp/opendata-latest.zip")

    class MissingData < StandardError; end

    attr_reader :path, :url

    def initialize(path: DEFAULT_PATH, url: URL)
      @path = Pathname(path)
      @url = url
    end

    def exist? = path.exist?
    def bytes = path.size

    # Downloads unless the archive is already here. Idempotent by design: the
    # caller decides when to refresh, so a re-run against the same file costs
    # nothing.
    def fetch!(force: false)
      return path if path.exist? && !force

      path.dirname.mkpath
      Rails.logger.info("[blender] downloading #{url}")
      IO.copy_stream(URI.parse(url).open("rb"), path.to_s)
      path
    end

    def sha256
      @sha256 ||= Digest::SHA256.file(path).hexdigest
    end

    # The JSONL member's name carries the snapshot date, e.g.
    # "opendata-2026-09-14-000000+0000.jsonl".
    def label
      @label ||= Zip::File.open(path) do |zip|
        entry = zip.glob("*.jsonl").first or raise MissingData, "no .jsonl member in #{path}"
        entry.name
      end
    end

    def taken_at
      label[/(\d{4}-\d{2}-\d{2})/, 1]&.then { |d| Time.zone.parse(d) }
    end

    # The licence shipped inside the archive. Read rather than assumed, so a
    # change upstream shows up instead of being papered over.
    def license_text
      Zip::File.open(path) { |zip| zip.glob("LICENSE.txt").first&.get_input_stream&.read }
    end

    def cc0?
      license_text.to_s.include?("CC0 1.0 Universal")
    end

    # Yields one parsed JSON record per line.
    def each_record
      return enum_for(:each_record) unless block_given?

      Zip::File.open(path) do |zip|
        entry = zip.glob("*.jsonl").first or raise MissingData, "no .jsonl member in #{path}"
        entry.get_input_stream do |io|
          io.each_line do |line|
            next if line.strip.empty?

            begin
              yield JSON.parse(line)
            rescue JSON::ParserError
              next
            end
          end
        end
      end
    end
  end
end
