# One raw measurement: a single scene from a single upstream submission.
#
# This is the evidence layer. Every displayed figure is explainable by clicking
# through to the rows here that produced it, so nothing is summarised away and
# nothing is deleted — ineligible rows are kept with the reason recorded, so a
# sample count can always be reconciled against the raw data.
class BenchmarkSubmission < ApplicationRecord
  belongs_to :source
  belongs_to :benchmark_version
  belongs_to :workload
  belongs_to :cpu, optional: true
  belongs_to :first_seen_run, class_name: "IngestRun", optional: true
  belongs_to :last_seen_run, class_name: "IngestRun", optional: true

  # Reasons a stored measurement is not aggregated. Each maps to a rule in
  # config/scoring.yml, so the published methodology and the data agree.
  THREAD_RESTRICTED = "thread_restricted".freeze
  MULTI_SOCKET = "multi_socket".freeze
  CRASHED = "crashed".freeze
  UNMATCHED_CPU = "unmatched_cpu".freeze

  validates :upstream_id, :raw_device_name, :metric_key, :benchmark_build, presence: true
  validates :value, presence: true
  validates :entry_index, uniqueness: { scope: :upstream_id }

  scope :eligible, -> { where(eligible: true).where.not(cpu_id: nil) }
  scope :for_score, ->(score) {
    where(cpu_id: score.cpu_id, benchmark_version_id: score.benchmark_version_id,
          workload_id: score.workload_id)
  }
  scope :recent_first, -> { order(measured_at: :desc) }

  def excluded? = !eligible?
end
