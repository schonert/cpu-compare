# One major benchmark series — the unit within which results are comparable.
#
# Aggregation never crosses a row of this table. Blender 4.x and 5.x are
# separate series because Cycles changes between majors; series 2.x is separate
# again because it predates the samples-per-minute metric entirely and is
# measured in seconds, where lower is better.
class BenchmarkVersion < ApplicationRecord
  belongs_to :benchmark_suite
  has_many :benchmark_submissions, dependent: :destroy
  has_many :benchmark_scores, dependent: :destroy

  SAMPLES_PER_MINUTE = "samples_per_minute".freeze
  RENDER_TIME = "render_time_seconds".freeze

  validates :series, :label, :metric_key, :metric_unit, presence: true
  validates :series, uniqueness: { scope: :benchmark_suite_id }

  scope :ordered, -> { order(Arel.sql("CAST(benchmark_versions.series AS INTEGER) DESC")) }

  def to_param = "#{benchmark_suite.key}-#{series}"

  # Workloads that actually carry scores in this series. The scene set changed
  # between majors — 2.x has seven, 3.x onward have three — so this is read
  # from the data rather than declared.
  def scored_workloads
    Workload.where(id: benchmark_scores.select(:workload_id)).order(:position, :key)
  end
end
