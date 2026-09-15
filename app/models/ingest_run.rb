# One ingest or scoring pass. Runs are never overwritten, so re-running against
# a newer snapshot adds to the history rather than replacing it — which is what
# makes "re-runnable without losing history" checkable after the fact.
class IngestRun < ApplicationRecord
  RUNNING = "running".freeze
  SUCCEEDED = "succeeded".freeze
  FAILED = "failed".freeze
  STATUSES = [RUNNING, SUCCEEDED, FAILED].freeze

  BLENDER_SNAPSHOT = "blender_snapshot".freeze
  WIKIDATA_SPECS = "wikidata_specs".freeze
  REPORTED_SPECS = "reported_specs".freeze
  SCORING = "scoring".freeze

  validates :source_key, :kind, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :succeeded, -> { where(status: SUCCEEDED) }
  scope :recent, -> { order(started_at: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind) }

  serialize :details, coder: JSON, type: Hash

  def self.latest_success(kind:) = succeeded.of_kind(kind).recent.first

  def duration
    return unless started_at && finished_at

    finished_at - started_at
  end

  def succeed!(**counts)
    update!(counts.merge(status: SUCCEEDED, finished_at: Time.current))
  end

  def fail!(error)
    update!(status: FAILED, finished_at: Time.current, error_message: error.to_s.truncate(2_000))
  end
end
