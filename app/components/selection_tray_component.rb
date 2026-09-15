# The row of chips showing what is currently being compared.
class SelectionTrayComponent < ApplicationComponent
  def initialize(comparison:, version:)
    @comparison = comparison
    @version = version
  end

  attr_reader :comparison, :version

  def slugs = comparison.slugs

  def slot_hint
    return if comparison.full?

    count = comparison.free_slots
    "#{count} more #{'slot'.pluralize(count)}"
  end
end
