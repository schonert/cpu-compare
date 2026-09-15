require "test_helper"

class Scoring::QuantilesTest < ActiveSupport::TestCase
  test "matches the linear-interpolation definition on an odd-sized sample" do
    values = [1, 2, 3, 4, 5]
    assert_equal 3.0, Scoring::Quantiles.median(values)
    assert_equal 2.0, Scoring::Quantiles.q1(values)
    assert_equal 4.0, Scoring::Quantiles.q3(values)
  end

  test "interpolates between order statistics on an even-sized sample" do
    values = [1, 2, 3, 4]
    assert_equal 2.5, Scoring::Quantiles.median(values)
    assert_equal 1.75, Scoring::Quantiles.q1(values)
    assert_equal 3.25, Scoring::Quantiles.q3(values)
  end

  test "handles one and zero samples" do
    assert_equal 7.0, Scoring::Quantiles.median([7])
    assert_nil Scoring::Quantiles.median([])
  end

  test "the median ignores an extreme low outlier that would drag a mean" do
    # The shape of a real Open Data group: a throttled run orders of magnitude
    # below the rest.
    values = [16.2, 195.0, 198.0, 199.5, 201.0].sort
    assert_equal 198.0, Scoring::Quantiles.median(values)
    assert_operator values.sum / values.size, :<, 170
  end
end
