ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    setup { BlenderOpenData::Catalog.install! }

    def blender_source = Source[Source::BLENDER_OPEN_DATA]
    def suite = BenchmarkSuite.blender
    def version(series = "4") = BenchmarkVersion.find_by!(benchmark_suite: suite, series: series)
    def workload(key = "monster") = Workload.find_by!(benchmark_suite: suite, key: key)

    def create_cpu(name:, **attrs)
      Cpu.create!(name: name, slug: name.parameterize, vendor: Cpu.vendor_for(name), **attrs)
    end

    # One measurement, defaulting to an eligible Blender 4.x run on Monster.
    def create_submission(cpu:, value:, series: "4", scene: "monster", **attrs)
      version = version(series)
      BenchmarkSubmission.create!(
        source: blender_source, benchmark_version: version, workload: workload(scene),
        cpu: cpu, upstream_id: SecureRandom.uuid, entry_index: 0,
        raw_device_name: cpu.name, value: value, metric_key: version.metric_key,
        benchmark_build: "#{series}.2.0", measured_at: Time.current,
        sockets: 1, device_threads: 16, system_threads: 16, **attrs
      )
    end

    # One upstream record in the v4 shape Open Data publishes today.
    def opendata_record(device: "AMD Ryzen 9 5950X 16-Core Processor", scenes: %w[monster],
                        blender: "4.2.0", device_type: "CPU", spm: 120.5, sockets: 1,
                        threads: 32, id: nil, schema: "v4")
      {
        "id" => id || SecureRandom.uuid,
        "schema_version" => schema,
        "created_at" => "2026-05-01T10:00:00+00:00",
        "data" => scenes.map do |scene|
          {
            "benchmark_launcher" => { "label" => "3.3.0" },
            "benchmark_script" => { "label" => "3.1.2" },
            "blender_version" => { "label" => blender, "version" => blender },
            "device_info" => {
              "compute_devices" => [{ "name" => device, "type" => "CPU" }],
              "device_type" => device_type, "num_cpu_threads" => threads
            },
            "scene" => { "label" => scene, "checksum" => "abc123" },
            "stats" => { "samples_per_minute" => spm, "render_time_no_sync" => 30.0,
                         "total_render_time" => 31.0, "number_of_samples" => 500,
                         "time_limit" => 30, "device_peak_memory" => 900 },
            "system_info" => { "num_cpu_cores" => 16, "num_cpu_sockets" => sockets,
                               "num_cpu_threads" => threads, "system" => "Linux" },
            "timestamp" => "2026-05-01T09:55:00+00:00"
          }
        end
      }
    end

    # The v1 shape: one device block with a nested scenes array.
    def opendata_v1_record(device: "Intel Xeon E5-2690", scenes: %w[bmw27 classroom], id: nil)
      {
        "id" => id || SecureRandom.uuid,
        "schema_version" => "v1",
        "created_at" => "2018-08-10T12:46:59+00:00",
        "data" => {
          "blender_version" => { "version" => "2.79 (sub 2)" },
          "device_info" => { "compute_devices" => [device], "device_type" => "CPU",
                             "num_cpu_threads" => 32 },
          "system_info" => { "num_cpu_cores" => 16, "num_cpu_sockets" => 1,
                             "num_cpu_threads" => 32, "system" => "Linux" },
          "scenes" => scenes.map do |scene|
            { "name" => scene,
              "stats" => { "render_time_no_sync" => 44.9, "total_render_time" => 46.5,
                           "result" => "OK" } }
          end
        }
      }
    end
  end
end
