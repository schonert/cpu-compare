require "test_helper"

class BlenderOpenData::ImporterTest < ActiveSupport::TestCase
  # Stands in for the zip so the tests do not need a 100 MB download.
  class FakeSnapshot
    attr_reader :records

    def initialize(records, cc0: true)
      @records = records
      @cc0 = cc0
    end

    def label = "opendata-2026-09-14-000000+0000.jsonl"
    def url = "https://opendata.blender.org/snapshots/opendata-latest.zip"
    def sha256 = Digest::SHA256.hexdigest(records.to_json)
    def bytes = 1234
    def taken_at = Time.zone.parse("2026-09-14")
    def cc0? = @cc0
    def each_record(&block) = records.each(&block)
  end

  def import(records, **opts) = BlenderOpenData::Importer.call(snapshot: FakeSnapshot.new(records, **opts))

  test "stores one submission per scene and resolves the processor" do
    run = import([opendata_record(scenes: %w[monster junkshop])])

    assert_equal IngestRun::SUCCEEDED, run.status
    assert_equal 2, BenchmarkSubmission.count
    assert_equal "AMD Ryzen 9 5950X", Cpu.sole.name
    assert_equal "AMD Ryzen 9 5950X 16-Core Processor", BenchmarkSubmission.first.raw_device_name
  end

  test "re-running against the same snapshot creates nothing new" do
    records = [opendata_record(id: "fixed-1", scenes: %w[monster junkshop])]
    import(records)

    before = [BenchmarkSubmission.count, Cpu.count, CpuAlias.count]
    import(records)

    assert_equal before, [BenchmarkSubmission.count, Cpu.count, CpuAlias.count]
  end

  test "a re-run preserves when a measurement was first seen and records the latest run" do
    records = [opendata_record(id: "fixed-2")]
    first = import(records)
    second = import(records)

    submission = BenchmarkSubmission.sole
    assert_equal first.id, submission.first_seen_run_id
    assert_equal second.id, submission.last_seen_run_id
  end

  test "ingest history survives a re-run" do
    records = [opendata_record(id: "fixed-3")]
    import(records)
    import(records)

    assert_equal 2, IngestRun.of_kind(IngestRun::BLENDER_SNAPSHOT).count
    assert_equal 2, IngestRun.succeeded.count
  end

  test "a newer snapshot adds measurements without losing the old ones" do
    import([opendata_record(id: "old-1")])
    import([opendata_record(id: "old-1"), opendata_record(id: "new-1", spm: 130.0)])

    assert_equal 2, BenchmarkSubmission.count
    assert_equal %w[new-1 old-1], BenchmarkSubmission.pluck(:upstream_id).sort
  end

  test "records a multi-socket run but excludes it from scoring" do
    import([opendata_record(sockets: 2)])

    submission = BenchmarkSubmission.sole
    refute_predicate submission, :eligible?
    assert_equal BenchmarkSubmission::MULTI_SOCKET, submission.exclusion_reason
    assert_empty BenchmarkSubmission.eligible
  end

  test "records a thread-restricted run but excludes it from scoring" do
    record = opendata_record(threads: 32)
    record["data"][0]["device_info"]["num_cpu_threads"] = 8

    import([record])
    assert_equal BenchmarkSubmission::THREAD_RESTRICTED, BenchmarkSubmission.sole.exclusion_reason
  end

  test "records an unidentifiable processor but excludes it from scoring" do
    import([opendata_record(device: "AMD Eng Sample: 100-000001593-40")])

    submission = BenchmarkSubmission.sole
    assert_nil submission.cpu_id
    assert_equal BenchmarkSubmission::UNMATCHED_CPU, submission.exclusion_reason
    # Kept rather than dropped, so normalisation coverage stays measurable.
    assert_equal 1, CpuAlias.unmatched.count
  end

  test "folds different spellings of one chip onto a single processor" do
    import([
      opendata_record(id: "a", device: "AMD Ryzen 9 5950X 16-Core Processor"),
      opendata_record(id: "b", device: "AMD Ryzen 9 5950X"),
      opendata_record(id: "c", device: "Ryzen 9 5950X")
    ])

    assert_equal 1, Cpu.count
    assert_equal 3, CpuAlias.count
    assert_equal 3, BenchmarkSubmission.where(cpu: Cpu.sole).count
  end

  test "files each major version against its own series" do
    import([opendata_record(id: "a", blender: "4.2.0"),
            opendata_record(id: "b", blender: "5.1.0"),
            opendata_v1_record(id: "c", scenes: %w[bmw27])])

    series = BenchmarkSubmission.joins(:benchmark_version)
                                .group("benchmark_versions.series").count
    assert_equal({ "2" => 1, "4" => 1, "5" => 1 }, series)
  end

  test "refuses to ingest a snapshot that is not CC0" do
    error = assert_raises(RuntimeError) { import([opendata_record], cc0: false) }
    assert_match(/not CC0/, error.message)
    assert_equal 0, BenchmarkSubmission.count
  end

  test "records the snapshot it read, so a run can be verified afterwards" do
    run = import([opendata_record])

    assert_equal "opendata-2026-09-14-000000+0000.jsonl", run.snapshot_label
    assert_equal 64, run.snapshot_sha256.length
    assert_equal Source::BLENDER_OPEN_DATA, run.source_key
  end

  test "a manual alias is honoured and not overwritten by a later ingest" do
    import([opendata_record(id: "a", device: "Weird Vendor XYZ-1")])
    intended = create_cpu(name: "Intel Core i9-14900K")
    CpuAlias.find_by!(raw_name: "Weird Vendor XYZ-1")
            .update!(cpu: intended, match_method: CpuAlias::MANUAL)

    import([opendata_record(id: "a", device: "Weird Vendor XYZ-1")])

    assert_equal intended.id, CpuAlias.find_by(raw_name: "Weird Vendor XYZ-1").cpu_id
    assert_equal CpuAlias::MANUAL, CpuAlias.find_by(raw_name: "Weird Vendor XYZ-1").match_method
  end
end
