require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  setup do
    @ryzen = create_cpu(name: "AMD Ryzen 9 5950X")
    @intel = create_cpu(name: "Intel Core i5-13600K")
    @epyc = create_cpu(name: "AMD EPYC 9755")
    [@ryzen, @intel, @epyc].each do |cpu|
      6.times { |i| create_submission(cpu: cpu, value: 100 + i) }
      6.times { |i| create_submission(cpu: cpu, value: 50 + i, scene: "junkshop") }
    end
    Scoring::Aggregator.call
    Rails.cache.clear
  end

  # Regression: `named_like` used an unqualified `name LIKE ?`, and the browse
  # query joins `workloads`, which has its own `name`. SQLite rejected it as
  # ambiguous, so every browse search 500'd.
  test "browse search filters instead of erroring" do
    get cpus_path(q: "5950")

    assert_response :success
    assert_match(/AMD Ryzen 9 5950X/, response.body)
    refute_match(/Intel Core i5-13600K/, response.body)
  end

  test "browse search works alongside the vendor filter" do
    get cpus_path(q: "ryzen", vendor: "amd")

    assert_response :success
    assert_match(/AMD Ryzen 9 5950X/, response.body)
    refute_match(/Intel Core i5-13600K/, response.body)
  end

  # Regression: `ranked` ordered on an unqualified `higher_is_better`, which
  # `benchmark_versions` also has — ambiguous once ordered over the join.
  test "browse search still ranks correctly over the version join" do
    get cpus_path(q: "AMD")

    assert_response :success
    assert_match(/AMD Ryzen 9 5950X/, response.body)
    assert_match(/AMD EPYC 9755/, response.body)
  end

  test "a search matching nothing says so rather than erroring" do
    get cpus_path(q: "zzznope")

    assert_response :success
    assert_match(/Nothing matches/, response.body)
  end

  test "the filtered count reflects the search, not the whole catalogue" do
    get cpus_path(q: "5950")
    assert_match(/1 processor\b/, response.body)

    get cpus_path
    assert_match(/3 processors/, response.body)
  end

  # Regression: the filter form carried no workload, so searching silently
  # reset the ranking to the first scene.
  test "searching keeps the workload being looked at" do
    get cpus_path(q: "AMD", workload: "junkshop")

    assert_response :success
    assert_select "input#filter_workload[value=?]", "junkshop"
    assert_match(/Junkshop/, response.body)
  end

  test "the workload tabs keep the current search" do
    get cpus_path(q: "AMD", workload: "junkshop")

    assert_select "a[href*=?]", "q=AMD"
  end

  # Regression: the Add links sit inside the results turbo-frame. Without
  # breaking out to _top, Turbo navigated the frame and merely replaced the
  # dropdown with the compare page's own empty search frame — so nothing
  # could be added from the dropdown.
  test "search result links break out of the turbo frame" do
    get search_cpus_path(q: "5950")

    assert_response :success
    assert_select "turbo-frame#cpu_search_results a[data-turbo-frame=?]", "_top"
  end

  test "a search result links to the compare page with the processor added" do
    get search_cpus_path(q: "5950")

    assert_select "a[href=?]", compare_path(cpus: @ryzen.slug)
  end

  test "a search result adds to the existing selection rather than replacing it" do
    get search_cpus_path(q: "13600K", cpus: @ryzen.slug)

    assert_select "a[href=?]", compare_path(cpus: "#{@ryzen.slug},#{@intel.slug}")
  end

  test "following an Add link renders the comparison" do
    get search_cpus_path(q: "5950")
    href = css_select("turbo-frame#cpu_search_results a").first["href"]

    get href
    assert_response :success
    assert_match(/AMD Ryzen 9 5950X/, response.body)
    assert_match(/samples\/min/, response.body)
  end

  test "search needs two characters before it returns anything" do
    get search_cpus_path(q: "5")

    assert_response :success
    assert_select "turbo-frame#cpu_search_results a", false
  end

  test "search only offers processors that have a published figure" do
    thin = create_cpu(name: "AMD Ryzen 3 3100")
    2.times { create_submission(cpu: thin, value: 10) }
    Scoring::Aggregator.call
    Rails.cache.clear

    get search_cpus_path(q: "3100")
    refute_match(/AMD Ryzen 3 3100/, response.body)
  end
end
