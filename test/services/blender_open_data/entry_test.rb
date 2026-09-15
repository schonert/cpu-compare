require "test_helper"

class BlenderOpenData::EntryTest < ActiveSupport::TestCase
  def entries(record) = BlenderOpenData::Entry.each_in(record).to_a

  test "reads a v4 record, one entry per scene" do
    record = opendata_record(scenes: %w[monster junkshop classroom], spm: 120.5)
    result = entries(record)

    assert_equal 3, result.size
    assert_equal %w[monster junkshop classroom], result.map(&:scene_key)
    assert_equal [0, 1, 2], result.map(&:entry_index)
    assert_equal "4", result.first.series
    assert_equal "4.2.0", result.first.build
    assert_equal "samples_per_minute", result.first.metric_key
    assert_in_delta 120.5, result.first.value, 0.001
  end

  test "reads a v1 record, whose scenes hang off one device block" do
    # v1 nests scenes, lists compute devices as plain strings, and has no
    # version label — only "2.79 (sub 2)".
    result = entries(opendata_v1_record(scenes: %w[bmw27 classroom]))

    assert_equal 2, result.size
    assert_equal "Intel Xeon E5-2690", result.first.raw_device_name
    assert_equal "2", result.first.series
    assert_equal "2.79 (sub 2)", result.first.build
    # 2.x predates samples-per-minute, so it is scored on render time.
    assert_equal "render_time_seconds", result.first.metric_key
    assert_in_delta 44.9, result.first.value, 0.001
  end

  test "skips GPU runs even though the record names a CPU" do
    # A HIP or CUDA run still lists the machine's processor in system_info;
    # device_type is the only reliable discriminator.
    assert_empty entries(opendata_record(device_type: "HIP"))
  end

  test "skips an entry with no usable figure" do
    record = opendata_record
    record["data"][0]["stats"] = { "device_peak_memory" => 900 }
    assert_empty entries(record)
  end

  test "reports a crashed scene so ingest can exclude it" do
    record = opendata_v1_record
    record["data"]["scenes"][0]["stats"]["result"] = "CRASH"
    assert_predicate entries(record).first, :crashed?
  end

  test "carries the machine details needed to judge eligibility" do
    entry = entries(opendata_record(sockets: 2, threads: 64)).first

    assert_equal 2, entry.sockets
    assert_equal 64, entry.device_threads
    assert_equal 64, entry.system_threads
    assert_equal "Linux", entry.operating_system
  end

  test "tolerates a record whose data is neither shape" do
    assert_empty entries({ "id" => "x", "schema_version" => "v9", "data" => "nonsense" })
  end
end
