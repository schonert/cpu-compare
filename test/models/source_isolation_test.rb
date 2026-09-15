require "test_helper"

# The separation between what may and may not be republished is structural, not
# a convention. These tests pin that down.
class SourceIsolationTest < ActiveSupport::TestCase
  test "PassMark is registered as licensed and not redistributable" do
    passmark = Source[Source::PASSMARK_LICENSED]
    assert_predicate passmark, :licensed?
    refute_predicate passmark, :redistributable?
    assert_predicate passmark, :isolated?
  end

  test "every source a displayed figure comes from is redistributable" do
    BenchmarkSuite.find_each do |suite|
      assert_predicate suite.source, :redistributable?,
                       "#{suite.name} publishes figures from a non-redistributable source"
    end
  end

  test "licensed results refuse to be stored against an unlicensed source" do
    result = LicensedBenchmarkResult.new(
      source: Source[Source::BLENDER_OPEN_DATA], vendor_reference: "1", cpu_name: "x",
      metric_key: "cpu_mark", value: 1, license_reference: "contract-1",
      retrieved_at: Time.current
    )

    refute_predicate result, :valid?
    assert_includes result.errors[:source], "must be a licensed source to be stored here"
  end

  test "a licensed result must name the licence it was obtained under" do
    result = LicensedBenchmarkResult.new(
      source: Source[Source::PASSMARK_LICENSED], vendor_reference: "1", cpu_name: "x",
      metric_key: "cpu_mark", value: 1, retrieved_at: Time.current
    )

    refute_predicate result, :valid?
    assert_includes result.errors[:license_reference], "can't be blank"
  end

  test "scores are computed only from benchmark_submissions" do
    cpu = create_cpu(name: "AMD Ryzen 9 5950X")
    5.times { create_submission(cpu: cpu, value: 100) }
    OpenbenchmarkingResult.create!(
      source: Source[Source::WIKIDATA], cpu: cpu, test_profile: "pts/blender",
      metric_key: "seconds", metric_unit: "s", higher_is_better: false,
      raw_device_name: cpu.name, median: 9_999, retrieved_at: Time.current
    )

    Scoring::Aggregator.call

    # The second source exists but cannot reach a published figure.
    assert_equal 1, BenchmarkScore.count
    assert_in_delta 100, BenchmarkScore.sole.median.to_f, 0.001
  end
end
