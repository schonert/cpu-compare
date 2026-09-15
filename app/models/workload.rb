# One scene. Scored on its own and displayed alongside the others, never
# averaged into a headline number.
class Workload < ApplicationRecord
  belongs_to :benchmark_suite
  has_many :benchmark_submissions, dependent: :destroy
  has_many :benchmark_scores, dependent: :destroy

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :benchmark_suite_id }

  scope :ordered, -> { order(:position, :key) }

  def to_param = key
end
