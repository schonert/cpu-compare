module BlenderOpenData
  # The fixed vocabulary: the sources we are allowed to use, the benchmark and
  # its protocol, the series, and the scenes.
  #
  # Declared here rather than inferred from the data so that a new scene or a
  # new major version shows up as an explicit decision — including the fact
  # that its results are not comparable with the previous one.
  module Catalog
    module_function

    SOURCES = [
      {
        key: Source::BLENDER_OPEN_DATA,
        name: "Blender Open Data",
        url: "https://opendata.blender.org/",
        license: "CC0-1.0",
        license_url: "https://creativecommons.org/publicdomain/zero/1.0/",
        redistributable: true,
        licensed: false,
        notes: "Public benchmark submissions released into the public domain. " \
               "The licence is verified from LICENSE.txt inside each snapshot at ingest."
      },
      {
        key: Source::BLENDER_REPORTED,
        name: "Reported by machines",
        url: "https://opendata.blender.org/",
        license: "CC0-1.0",
        license_url: "https://creativecommons.org/publicdomain/zero/1.0/",
        redistributable: true,
        licensed: false,
        notes: "Core and thread counts read back out of the benchmark submissions: every " \
               "run records the machine it ran on. Taken as the most commonly reported " \
               "value across a processor's runs, which shrugs off the VMs and restricted " \
               "containers that under-report. A measured figure, not a vendor specification, " \
               "so a vendor source outranks it wherever we have one."
      },
      {
        key: Source::WIKIDATA,
        name: "Wikidata",
        url: "https://www.wikidata.org/",
        license: "CC0-1.0",
        license_url: "https://creativecommons.org/publicdomain/zero/1.0/",
        redistributable: true,
        licensed: false,
        notes: "Structured specifications. Coverage is thin — a few hundred CPU models " \
               "carry core counts and fewer carry clocks or prices — so most of the " \
               "catalogue has benchmark scores and no spec sheet."
      },
      {
        key: Source::INTEL_ARK,
        name: "Intel ARK",
        url: "https://ark.intel.com/",
        license: "Intel terms of use",
        redistributable: true,
        licensed: false,
        notes: "Vendor specifications for Intel parts. No importer yet: specs may be " \
               "entered through cpu_specs with this source and a statement URL."
      },
      {
        key: Source::AMD_PRODUCT,
        name: "AMD product pages",
        url: "https://www.amd.com/en/products/specifications/processors",
        license: "AMD terms of use",
        redistributable: true,
        licensed: false,
        notes: "Vendor specifications for AMD parts. No importer yet: specs may be " \
               "entered through cpu_specs with this source and a statement URL."
      },
      {
        key: Source::PASSMARK_LICENSED,
        name: "PassMark (licensed CSV)",
        url: "https://www.cpubenchmark.net/",
        terms_url: "https://www.passmark.com/legal/terms.htm",
        license: "Commercial licence required",
        redistributable: false,
        licensed: true,
        notes: "Not ingested. PassMark's public pages may not be redistributed. If this " \
               "data is ever wanted it must come through their paid CSV licensing and is " \
               "stored only in licensed_benchmark_results, flagged as licensed, and never " \
               "aggregated into a score."
      }
    ].freeze

    PROTOCOL = <<~TEXT.strip
      The Blender Benchmark launcher renders a fixed set of scenes with Cycles on the
      CPU and reports throughput. From Blender 3.0 the published figure is samples per
      minute over a fixed time limit; before that the launcher reported render time in
      seconds. Submissions are uploaded by the public, so the same processor appears
      under many machines, thermal conditions and operating systems.
    TEXT

    VERSIONS = [
      { series: "5", label: "Blender 5.x", metric_key: BenchmarkVersion::SAMPLES_PER_MINUTE,
        metric_unit: "samples/min", higher_is_better: true },
      { series: "4", label: "Blender 4.x", metric_key: BenchmarkVersion::SAMPLES_PER_MINUTE,
        metric_unit: "samples/min", higher_is_better: true },
      { series: "3", label: "Blender 3.x", metric_key: BenchmarkVersion::SAMPLES_PER_MINUTE,
        metric_unit: "samples/min", higher_is_better: true },
      { series: "2", label: "Blender 2.x", metric_key: BenchmarkVersion::RENDER_TIME,
        metric_unit: "s", higher_is_better: false,
        notes: "Predates the samples-per-minute metric: 2.x reported render time in " \
               "seconds, so lower is better and the figures share no scale with any " \
               "later series. A different scene set as well." }
    ].freeze

    NOT_COMPARABLE = <<~TEXT.strip
      Cycles changes between major versions, so the same scene renders at a different
      speed on a different major even on identical hardware. Results are only ever
      aggregated within one series.
    TEXT

    # Scene sets differ by series; both sets are declared, and which scenes a
    # series actually used is read from the scored data.
    WORKLOADS = [
      { key: "monster", name: "Monster", position: 1,
        description: "Character scene with hair and heavy shading. Used from Blender 3.0." },
      { key: "junkshop", name: "Junkshop", position: 2,
        description: "Cluttered interior with many textures. Used from Blender 3.0." },
      { key: "classroom", name: "Classroom", position: 3,
        description: "Interior with diffuse bounce lighting. Used across every series." },
      { key: "bmw27", name: "BMW27", position: 4, description: "Car render. Blender 2.x scene set." },
      { key: "fishy_cat", name: "Fishy Cat", position: 5, description: "Blender 2.x scene set." },
      { key: "koro", name: "Koro", position: 6, description: "Blender 2.x scene set." },
      { key: "pavillon_barcelona", name: "Pavillon Barcelona", position: 7,
        description: "Blender 2.x scene set." },
      { key: "victor", name: "Victor", position: 8, description: "Blender 2.x scene set." },
      { key: "barbershop_interior", name: "Barbershop Interior", position: 9,
        description: "Blender 2.x scene set." }
    ].freeze

    # Idempotent: safe to call before every ingest.
    def install!
      SOURCES.each do |attrs|
        Source.find_or_initialize_by(key: attrs[:key]).update!(attrs)
      end

      suite = BenchmarkSuite.find_or_initialize_by(key: BenchmarkSuite::BLENDER)
      suite.update!(source: Source[Source::BLENDER_OPEN_DATA],
                    name: "Blender Benchmark (Cycles)",
                    protocol: PROTOCOL,
                    protocol_url: "https://opendata.blender.org/about/")

      VERSIONS.each do |attrs|
        version = BenchmarkVersion.find_or_initialize_by(benchmark_suite: suite, series: attrs[:series])
        version.update!(attrs.reverse_merge(notes: NOT_COMPARABLE))
      end

      WORKLOADS.each do |attrs|
        Workload.find_or_initialize_by(benchmark_suite: suite, key: attrs[:key]).update!(attrs)
      end

      suite
    end
  end
end
