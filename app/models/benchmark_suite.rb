# A named measurement protocol — "benchmark" in the scoring key
# (cpu, benchmark, benchmark_version, workload).
#
# Named BenchmarkSuite rather than Benchmark because Ruby's stdlib already owns
# that constant and Rails calls into it.
#
# The requirement that every number traces back to a named protocol is why
# `protocol` is NOT NULL: there is no way to record a measurement without
# saying what procedure produced it.
class BenchmarkSuite < ApplicationRecord
  belongs_to :source
  has_many :benchmark_versions, dependent: :destroy
  has_many :workloads, -> { order(:position, :key) }, dependent: :destroy

  BLENDER = "blender".freeze

  validates :key, :name, :protocol, presence: true
  validates :key, uniqueness: true

  def self.blender = find_by(key: BLENDER)
  def to_param = key
end
