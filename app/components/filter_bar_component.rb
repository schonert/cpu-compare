# Browse filters. Plain GET form, so every filtered view has its own URL.
class FilterBarComponent < ApplicationComponent
  def initialize(filters:, selected:, version:, workload:, total:)
    @filters = filters
    @selected = selected
    @version = version
    @workload = workload
    @total = total
  end

  attr_reader :filters, :selected, :version, :workload, :total

  def vendor_options = Catalogue.vendors.map { |v| [Cpu.vendor_label_for(v), v] }

  def field_classes = "rounded-full bg-panel px-4 py-2 text-[13px] text-ink"

  def total_label
    "#{number_with_delimiter(total)} #{'processor'.pluralize(total)}"
  end
end
