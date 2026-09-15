# Browse filters. Plain GET form, so every filtered view has its own URL.
class FilterBarComponent < ApplicationComponent
  def initialize(filters:, selected:, version:, workload:)
    @filters = filters
    @selected = selected
    @version = version
    @workload = workload
  end

  attr_reader :filters, :selected, :version, :workload

  def vendor_options = Catalogue.vendors.map { |v| [Cpu.vendor_label_for(v), v] }

  def field_classes = "field"
end
