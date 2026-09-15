# Commercially licensed benchmark data — PassMark's paid CSV is the case this
# exists for.
#
# Isolated by design: never joined into `benchmark_scores`, never aggregated
# with anything else, and every row must name the licence it was obtained
# under. The UI flags anything from here as licensed.
class LicensedBenchmarkResult < ApplicationRecord
  belongs_to :source
  belongs_to :cpu, optional: true

  validates :vendor_reference, :cpu_name, :metric_key, :license_reference, presence: true
  validates :value, :retrieved_at, presence: true
  validate :source_must_be_licensed

  private

  def source_must_be_licensed
    return if source.nil? || source.licensed?

    errors.add(:source, "must be a licensed source to be stored here")
  end
end
