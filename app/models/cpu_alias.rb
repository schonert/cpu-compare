# Every raw device string the ingest has ever seen, and what it resolved to.
#
# Unmatched strings are kept with a null cpu_id rather than dropped, so
# normalisation coverage is a number you can query rather than a guess. This
# table is also the manual-override point: set cpu_id and match_method to
# "manual" and the next ingest honours it.
class CpuAlias < ApplicationRecord
  belongs_to :cpu, optional: true

  # How the raw string was resolved.
  EXACT = "exact".freeze       # normalised form matched a canonical name exactly
  RULE = "rule".freeze         # matched after applying the normalisation rules
  MANUAL = "manual".freeze     # a human set this, and ingest must not overwrite it
  UNMATCHED = "unmatched".freeze

  METHODS = [EXACT, RULE, MANUAL, UNMATCHED].freeze

  validates :raw_name, :normalized_name, presence: true
  validates :raw_name, uniqueness: true
  validates :match_method, inclusion: { in: METHODS }

  scope :unmatched, -> { where(cpu_id: nil) }
  scope :manual, -> { where(match_method: MANUAL) }

  def manual? = match_method == MANUAL
end
