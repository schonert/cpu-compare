# Where a fact came from, and whether we are allowed to republish it.
#
# Every stored value points at one of these. `redistributable` is the gate the
# rest of the app checks: anything the site renders must trace to a source
# where it is true.
class Source < ApplicationRecord
  has_many :benchmarks, dependent: :restrict_with_exception
  has_many :benchmark_submissions, dependent: :restrict_with_exception
  has_many :cpu_specs, dependent: :restrict_with_exception

  BLENDER_OPEN_DATA = "blender_open_data".freeze
  # Specifications read back out of the benchmark submissions themselves,
  # rather than stated by a vendor. Same licence, different kind of claim.
  BLENDER_REPORTED = "blender_reported".freeze
  WIKIDATA = "wikidata".freeze
  INTEL_ARK = "intel_ark".freeze
  AMD_PRODUCT = "amd_product".freeze
  PASSMARK_LICENSED = "passmark_licensed".freeze

  validates :key, :name, :license, presence: true
  validates :key, uniqueness: true

  scope :redistributable, -> { where(redistributable: true) }

  def self.[](key) = find_by!(key: key)

  # A licensed source may be stored, but only in its own table and only with a
  # licence reference attached.
  def isolated? = licensed?
end
