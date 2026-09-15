# One sourced fact about one CPU: the value, where it came from, a deep link to
# the exact statement, and when it was read.
#
# Two sources are allowed to disagree — both rows are kept, and `precedence`
# decides which one is materialised onto the `cpus` table. That keeps the
# disagreement visible instead of silently resolving it at import time.
class CpuSpec < ApplicationRecord
  belongs_to :cpu
  belongs_to :source

  validates :spec_key, presence: true
  validates :spec_key, inclusion: { in: Cpu::SPEC_ATTRIBUTES }
  validates :retrieved_at, presence: true
  validate  :must_carry_a_value

  scope :for_key, ->(key) { where(spec_key: key) }
  scope :preferred, -> { order(precedence: :desc, retrieved_at: :desc) }

  def value = value_numeric || value_text || value_date

  # Formatted with its unit, which the presentation contract requires wherever
  # the figure is shown.
  def display_value
    return value_date&.strftime("%-d %b %Y") if value_date
    return value_text if value_text

    number = value_numeric
    return if number.nil?

    number = number.to_i if number == number.to_i
    [number, unit].compact.join(" ")
  end

  private

  def must_carry_a_value
    return if value_numeric.present? || value_text.present? || value_date.present?

    errors.add(:base, "a spec row must carry a numeric, text or date value")
  end
end
