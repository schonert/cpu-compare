module Scoring
  # Quantiles by linear interpolation between order statistics — the R type-7 /
  # numpy default definition, named in config/scoring.yml and published at
  # /methodology because "the IQR" is ambiguous otherwise.
  module Quantiles
    module_function

    # `sorted` must already be ascending; the aggregator sorts in SQL.
    def at(sorted, fraction)
      return if sorted.empty?
      return sorted.first.to_f if sorted.size == 1

      position = (sorted.size - 1) * fraction
      low = position.floor
      high = position.ceil
      return sorted[low].to_f if low == high

      sorted[low].to_f + ((position - low) * (sorted[high].to_f - sorted[low].to_f))
    end

    def median(sorted) = at(sorted, 0.5)
    def q1(sorted) = at(sorted, 0.25)
    def q3(sorted) = at(sorted, 0.75)
  end
end
