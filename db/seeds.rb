# Installs the source, benchmark and workload vocabulary.
#
# Measurements are not seeded: the Blender snapshot is ~100 MB and is not
# checked in, so a fresh database starts empty and is filled by
#
#   bin/rails ingest:all
#
# which downloads the snapshot, ingests it, pulls specifications and scores.
BlenderOpenData::Catalog.install!

puts "Installed #{Source.count} sources, #{BenchmarkSuite.count} benchmark, " \
     "#{BenchmarkVersion.count} versions and #{Workload.count} workloads."
puts "Run `bin/rails ingest:all` to fetch and score the Blender Open Data snapshot."
