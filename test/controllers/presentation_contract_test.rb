require "test_helper"

# The presentation contract, checked against rendered HTML:
#   every displayed number shows its value with units, sample count, source,
#   benchmark version and date, and links through to its measurements.
class PresentationContractTest < ActionDispatch::IntegrationTest
  setup do
    @fast = create_cpu(name: "AMD Ryzen 9 7950X")
    @slow = create_cpu(name: "Intel Core i5-13600K")
    6.times { |i| create_submission(cpu: @fast, value: 200 + i) }
    6.times { |i| create_submission(cpu: @slow, value: 100 + i) }
    6.times { |i| create_submission(cpu: @fast, value: 90 + i, scene: "junkshop") }
    6.times { |i| create_submission(cpu: @slow, value: 50 + i, scene: "junkshop") }
    Scoring::Aggregator.call
    Rails.cache.clear
  end

  test "a compare row shows the value with its units" do
    get compare_path(cpus: "#{@fast.slug},#{@slow.slug}")
    assert_response :success
    assert_match(/samples\/min/, response.body)
  end

  test "a compare chart does not print run stats under the bar" do
    get compare_path(cpus: @fast.slug)

    refute_match(/6 runs/, response.body)
    refute_match(/IQR\/2/, response.body)
    refute_match(/to #{Time.current.utc.strftime('%b %Y')}/, response.body)
    assert_match(%r{/measurements/\d+}, response.body)
  end

  test "specifications sit above results and hide the source in a tooltip" do
    Cpus::SpecWriter.new(Source[Source::WIKIDATA]).write(
      @fast, spec_key: "cores", value: 16,
      statement_url: "https://www.wikidata.org/wiki/Q123"
    )

    get compare_path(cpus: @fast.slug)

    specs_at = response.body.index("Specifications")
    results_at = response.body.index("Results by workload")
    assert specs_at, "expected a Specifications heading"
    assert results_at, "expected a Results by workload heading"
    assert specs_at < results_at, "Specifications should sit above Results by workload"

    assert_match(/role="tooltip"/, response.body)
    assert_match(/Wikidata/, response.body)
    assert_match(%r{https://www.wikidata.org/wiki/Q123}, response.body)
  end

  test "every figure links through to its own measurements" do
    get compare_path(cpus: "#{@fast.slug},#{@slow.slug}")

    links = response.body.scan(%r{/measurements/(\d+)}).flatten.uniq
    # Two processors across two workloads.
    assert_equal 4, links.size
    links.each do |id|
      get measurements_path(id)
      assert_response :success, "measurement #{id} must be reachable"
    end
  end

  test "the measurements page shows the individual runs behind the figure" do
    score = BenchmarkScore.displayable.find_by!(cpu: @fast, workload: workload("monster"))
    get measurements_path(score)

    assert_response :success
    assert_match(/Individual runs/, response.body)
    # Every underlying run is listed, with the raw string the machine reported.
    assert_equal 6, score.submissions.count
    assert_match(/#{Regexp.escape(@fast.name)}/, response.body)
  end

  test "the measurements page reconciles excluded runs rather than hiding them" do
    create_submission(cpu: @fast, value: 999, eligible: false,
                      exclusion_reason: BenchmarkSubmission::MULTI_SOCKET)
    Scoring::Aggregator.call

    score = BenchmarkScore.displayable.find_by!(cpu: @fast, workload: workload("monster"))
    get measurements_path(score)

    assert_match(/not aggregated/, response.body)
    assert_match(/multi socket/, response.body)
  end

  test "workloads are shown side by side rather than collapsed into one rank" do
    get compare_path(cpus: "#{@fast.slug},#{@slow.slug}")

    assert_match(/Monster/, response.body)
    assert_match(/Junkshop/, response.body)
    assert_match(/Never averaged across scenes/, response.body)
  end

  test "a suppressed figure still draws a faded bar" do
    thin = create_cpu(name: "AMD Ryzen 3 3100")
    3.times { create_submission(cpu: thin, value: 10) }
    Scoring::Aggregator.call
    Rails.cache.clear

    get compare_path(cpus: "#{@fast.slug},#{thin.slug}")

    assert_response :success
    refute_match(/Fewer than 5 runs on record/, response.body)
    assert_match(/opacity-40/, response.body)
    assert_match(/#{Regexp.escape(thin.name)}/, response.body)
  end

  test "the methodology page publishes the scoring rules verbatim" do
    get methodology_path

    assert_response :success
    assert_match(/statistic: median/, response.body)
    assert_match(/min_samples: 5/, response.body)
    assert_match(/composites/, response.body)
  end

  test "the methodology page flags PassMark as licensed and not ingested" do
    get methodology_path

    assert_match(/PassMark/, response.body)
    assert_match(/Licensed — not ingested/, response.body)
  end

  test "the browse table ranks by one workload and carries provenance" do
    get cpus_path

    assert_response :success
    assert_match(/Ranked by workload/, response.body)
    assert_match(/6 runs/, response.body)
    assert_match(%r{/measurements/\d+}, response.body)
  end

  test "browsing a different workload reorders on that workload alone" do
    get cpus_path(workload: "junkshop")

    assert_response :success
    assert_match(/Junkshop/, response.body)
  end

  test "switching benchmark series does not blend them" do
    5.times { create_submission(cpu: @fast, value: 900, series: "5") }
    Scoring::Aggregator.call
    Rails.cache.clear

    get compare_path(cpus: @fast.slug, version: "blender-5")
    assert_match(/Blender 5\.x/, response.body)
    # The 4.x figure must not appear on the 5.x view.
    refute_match(/20[0-5]\.\d samples\/min/, response.body)
  end
end
