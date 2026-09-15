require "test_helper"

class Scoring::AggregatorTest < ActiveSupport::TestCase
  test "stores the median, quartiles and spread of the eligible submissions" do
    cpu = create_cpu(name: "AMD Ryzen 9 5950X")
    [16.2, 195.0, 198.0, 199.5, 201.0].each { |v| create_submission(cpu: cpu, value: v) }

    Scoring::Aggregator.call
    score = BenchmarkScore.sole

    assert_equal 5, score.sample_count
    assert_in_delta 198.0, score.median.to_f, 0.001
    assert_in_delta 195.0, score.q1.to_f, 0.001
    assert_in_delta 199.5, score.q3.to_f, 0.001
    assert_in_delta 4.5, score.iqr.to_f, 0.001
    assert_in_delta 16.2, score.minimum.to_f, 0.001
    assert_in_delta 201.0, score.maximum.to_f, 0.001
  end

  test "the median is used rather than the mean" do
    cpu = create_cpu(name: "AMD Ryzen 7 5800X")
    # One throttled run of the kind Open Data is full of.
    [16.2, 195.0, 198.0, 199.5, 201.0].each { |v| create_submission(cpu: cpu, value: v) }
    Scoring::Aggregator.call

    mean = (16.2 + 195.0 + 198.0 + 199.5 + 201.0) / 5
    assert_in_delta 198.0, BenchmarkScore.sole.median.to_f, 0.001
    refute_in_delta mean, BenchmarkScore.sole.median.to_f, 1.0
  end

  test "suppresses a score below the configured sample threshold but keeps it" do
    cpu = create_cpu(name: "Intel Core i5-13600K")
    4.times { create_submission(cpu: cpu, value: 100) }
    Scoring::Aggregator.call

    score = BenchmarkScore.sole
    assert_predicate score, :suppressed?
    assert_equal 4, score.sample_count
    assert_equal 5, score.min_samples
    assert_empty BenchmarkScore.displayable
  end

  test "publishes a score once it reaches the threshold" do
    cpu = create_cpu(name: "Intel Core i9-14900K")
    5.times { create_submission(cpu: cpu, value: 100) }
    Scoring::Aggregator.call

    refute_predicate BenchmarkScore.sole, :suppressed?
    assert_equal 1, BenchmarkScore.displayable.count
  end

  test "never mixes results across major benchmark versions" do
    cpu = create_cpu(name: "AMD Ryzen 5 7600X")
    5.times { create_submission(cpu: cpu, value: 100, series: "4") }
    5.times { create_submission(cpu: cpu, value: 500, series: "5") }

    Scoring::Aggregator.call

    assert_equal 2, BenchmarkScore.count
    by_series = BenchmarkScore.includes(:benchmark_version).index_by { |s| s.benchmark_version.series }
    assert_in_delta 100, by_series["4"].median.to_f, 0.001
    assert_in_delta 500, by_series["5"].median.to_f, 0.001
  end

  test "never mixes results across workloads" do
    cpu = create_cpu(name: "AMD Ryzen 5 5600X")
    5.times { create_submission(cpu: cpu, value: 100, scene: "monster") }
    5.times { create_submission(cpu: cpu, value: 40, scene: "classroom") }

    Scoring::Aggregator.call

    assert_equal 2, BenchmarkScore.count
    by_scene = BenchmarkScore.includes(:workload).index_by { |s| s.workload.key }
    assert_in_delta 100, by_scene["monster"].median.to_f, 0.001
    assert_in_delta 40, by_scene["classroom"].median.to_f, 0.001
  end

  test "carries the metric and direction of its benchmark version" do
    cpu = create_cpu(name: "Intel Xeon W3680")
    5.times { create_submission(cpu: cpu, value: 50, series: "2", scene: "bmw27") }
    Scoring::Aggregator.call

    score = BenchmarkScore.sole
    # 2.x is measured in seconds, where lower is better — the opposite of 4.x.
    assert_equal "render_time_seconds", score.metric_key
    assert_equal "s", score.metric_unit
    refute score.higher_is_better
  end

  test "ignores submissions that were excluded at ingest" do
    cpu = create_cpu(name: "AMD EPYC 7763")
    5.times { create_submission(cpu: cpu, value: 100) }
    3.times do
      create_submission(cpu: cpu, value: 999, eligible: false,
                        exclusion_reason: BenchmarkSubmission::MULTI_SOCKET)
    end

    Scoring::Aggregator.call
    score = BenchmarkScore.sole
    assert_equal 5, score.sample_count
    assert_in_delta 100, score.median.to_f, 0.001
  end

  test "recomputing is idempotent and leaves one row per scoring key" do
    cpu = create_cpu(name: "AMD Ryzen 9 7950X")
    5.times { create_submission(cpu: cpu, value: 100) }

    Scoring::Aggregator.call
    first = BenchmarkScore.sole
    Scoring::Aggregator.call

    assert_equal 1, BenchmarkScore.count
    assert_equal first.id, BenchmarkScore.sole.id
  end

  test "records the date range of the measurements behind the figure" do
    cpu = create_cpu(name: "Apple M1")
    create_submission(cpu: cpu, value: 10, measured_at: 3.years.ago)
    4.times { create_submission(cpu: cpu, value: 10, measured_at: 1.day.ago) }

    Scoring::Aggregator.call
    score = BenchmarkScore.sole
    assert_operator score.measured_from, :<, 2.years.ago
    assert_operator score.measured_to, :>, 2.days.ago
  end

  test "removes a score whose submissions have all become ineligible" do
    cpu = create_cpu(name: "AMD Ryzen 3 3100")
    5.times { create_submission(cpu: cpu, value: 100) }
    Scoring::Aggregator.call
    assert_equal 1, BenchmarkScore.count

    BenchmarkSubmission.update_all(eligible: false, exclusion_reason: "unmatched_cpu")
    Scoring::Aggregator.call

    assert_equal 0, BenchmarkScore.count, "a figure must not outlive its evidence"
  end
end
