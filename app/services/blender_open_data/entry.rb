module BlenderOpenData
  # Flattens one upstream record into one measurement per scene.
  #
  # Open Data has four record schemas in the same file, and they disagree about
  # nearly everything:
  #
  #   v1  data is an object with a `scenes` array; compute_devices are plain
  #       strings; there is no version label, only "2.79 (sub 2)"; each scene
  #       carries a result flag.
  #   v2  as v1, but compute_devices are objects with a name and no type.
  #   v3  data is an array with one object per scene; scene.label and
  #       blender_version.label appear; render times only.
  #   v4  as v3, plus samples_per_minute — the metric Open Data publishes today.
  #
  # Rather than branch at every call site, everything is normalised here into
  # one flat shape, and the metric is chosen from the series: 3.x and later are
  # measured in samples per minute (higher is better), 2.x only ever reported
  # seconds (lower is better). The two are never combined.
  class Entry
    # 2.x predates samples-per-minute. `render_time_no_sync` rather than the
    # total is the comparable figure: it excludes scene sync, which is disk and
    # driver time, not render throughput.
    METRIC_BY_SERIES = Hash.new(BenchmarkVersion::SAMPLES_PER_MINUTE).merge(
      "2" => BenchmarkVersion::RENDER_TIME
    ).freeze

    attr_reader :upstream_id, :entry_index, :scene_key, :series, :build, :raw_device_name,
                :metric_key, :value, :samples_per_minute, :render_time_seconds,
                :total_render_time_seconds, :number_of_samples, :time_limit_seconds,
                :device_peak_memory_mb, :device_threads, :system_threads, :system_cores,
                :sockets, :operating_system, :launcher_version, :script_version,
                :scene_checksum, :schema_version, :measured_at, :result

    # Yields an Entry per scene in the record, skipping anything that is not a
    # CPU run or carries no usable figure.
    def self.each_in(record)
      return enum_for(:each_in, record) unless block_given?

      schema = record["schema_version"]
      id = record["id"]
      created = record["created_at"]

      rows(record).each_with_index do |row, index|
        entry = new(row, upstream_id: id, entry_index: index, schema_version: schema,
                          fallback_time: created)
        yield entry if entry.usable?
      end
    end

    # Normalises the two record layouts into a common list of per-scene hashes.
    def self.rows(record)
      data = record["data"]

      case data
      when Hash # v1 / v2: one device block, many scenes hanging off it
        Array(data["scenes"]).map do |scene|
          {
            "scene" => { "label" => scene["name"] },
            "stats" => scene["stats"] || {},
            "blender_version" => data["blender_version"] || {},
            "device_info" => data["device_info"] || {},
            "system_info" => data["system_info"] || {},
            "benchmark_launcher" => data["benchmark_launcher"] || {},
            "benchmark_script" => data["benchmark_script"] || {},
            "timestamp" => data["timestamp"]
          }
        end
      when Array # v3 / v4: already one entry per scene
        data.select { |e| e.is_a?(Hash) }
      else
        []
      end
    end

    def initialize(row, upstream_id:, entry_index:, schema_version:, fallback_time: nil)
      @upstream_id = upstream_id
      @entry_index = entry_index
      @schema_version = schema_version

      stats = row["stats"] || {}
      version = row["blender_version"] || {}
      device = row["device_info"] || {}
      system = row["system_info"] || {}

      @device_type = device["device_type"]
      @scene_key = row.dig("scene", "label")
      @scene_checksum = row.dig("scene", "checksum")
      @build = version["label"].presence || version["version"].presence
      @series = @build.to_s.split(" ").first.to_s.split(".").first.presence
      @raw_device_name = self.class.device_name(device)

      @samples_per_minute = stats["samples_per_minute"]
      @render_time_seconds = stats["render_time_no_sync"]
      @total_render_time_seconds = stats["total_render_time"]
      @number_of_samples = stats["number_of_samples"]
      @time_limit_seconds = stats["time_limit"]
      @device_peak_memory_mb = stats["device_peak_memory"]
      @result = stats["result"]

      @metric_key = METRIC_BY_SERIES[@series]
      @value = @metric_key == BenchmarkVersion::SAMPLES_PER_MINUTE ? @samples_per_minute : @render_time_seconds

      @device_threads = device["num_cpu_threads"]
      @system_threads = system["num_cpu_threads"]
      @system_cores = system["num_cpu_cores"]
      @sockets = system["num_cpu_sockets"]
      @operating_system = system["system"].presence

      @launcher_version = row.dig("benchmark_launcher", "label")
      @script_version = row.dig("benchmark_script", "label")
      @measured_at = parse_time(row["timestamp"] || fallback_time)
    end

    # The CPU's name. v1 lists plain strings; v2 objects without a type; v3/v4
    # objects tagged "CPU". On a CPU run every compute device is the same chip,
    # so the first is enough.
    def self.device_name(device)
      Array(device["compute_devices"]).each do |d|
        return d if d.is_a?(String) && d.present?
        return d["name"] if d.is_a?(Hash) && d["name"].present? && [nil, "CPU"].include?(d["type"])
      end
      nil
    end

    def cpu_run? = @device_type == "CPU"
    def crashed? = result.to_s.casecmp?("CRASH")

    # Stored only if it is a CPU run we can file and score.
    def usable?
      cpu_run? && scene_key.present? && series.present? &&
        raw_device_name.present? && value.present? && value.to_f.positive?
    end

    private

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
