# One aggregated figure, keyed exactly on
# (cpu, benchmark version, workload, metric) — never blended across any of them.
#
# Carries the spread and the sample count alongside the median so the number can
# be read with its uncertainty, and the thresholds that were in force when it
# was computed so an old figure stays explainable after the config moves on.
class BenchmarkScore < ApplicationRecord
  belongs_to :cpu
  belongs_to :benchmark_version
  belongs_to :workload
  belongs_to :ingest_run, optional: true

  validates :sample_count, :median, :metric_key, :metric_unit, presence: true

  # The only scope the UI is allowed to render from.
  scope :displayable, -> { where(suppressed: false) }
  scope :for_version, ->(v) { where(benchmark_version: v) }
  scope :for_workload, ->(w) { where(workload: w) }
  # Fully qualified: `benchmark_versions` carries its own `higher_is_better`, so
  # an unqualified one is ambiguous as soon as this is ordered over a join.
  scope :ranked, lambda {
    order(Arel.sql("CASE WHEN benchmark_scores.higher_is_better " \
                   "THEN -benchmark_scores.median ELSE benchmark_scores.median END"))
  }

  delegate :key, to: :workload, prefix: true

  # The raw measurements behind this figure. This is the click-through the
  # presentation contract requires.
  def submissions
    BenchmarkSubmission.eligible.for_score(self)
  end

  def value = median

  # Half the interquartile range as a ± figure, which is how the spread reads
  # most naturally next to a median.
  def spread
    return if q1.nil? || q3.nil?

    ((q3 - q1) / 2).round(2)
  end

  def relative_spread
    return if iqr.nil? || median.nil? || median.zero?

    (iqr / median * 100).round(1)
  end

  def last_updated_at = measured_to || computed_at
end
