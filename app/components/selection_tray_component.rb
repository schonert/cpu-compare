# The row of chips showing what is currently being compared.
class SelectionTrayComponent < ApplicationComponent
  def initialize(comparison:, version:)
    @comparison = comparison
    @version = version
  end

  attr_reader :comparison, :version

  def slugs = comparison.slugs
end
