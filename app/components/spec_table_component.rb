# Reference specifications for the compared CPUs.
#
# Every cell cites the source it came from, because a spec figure is a claim
# like any other. The citation lives in a tooltip on the value rather than as
# a footnote under it. Where nothing is known the table says so rather than
# printing a grid of dashes — Wikidata covers only a few hundred parts, so an
# empty spec sheet is the common case, not a failure.
class SpecTableComponent < ApplicationComponent
  def initialize(comparison:)
    @comparison = comparison
  end

  attr_reader :comparison

  def render? = comparison.cpus.any?

  def rows = comparison.spec_rows
  def cpus = comparison.cpus
  def empty? = comparison.spec_sheet_empty?

  def cell_value(row, cpu)
    value = row.value_for(cpu)
    return tag.span("—", class: "text-ink-faint") if value.blank?

    format_metric(value, format: row.format, unit: row.unit)
  end

  def source_label(row, cpu)
    row.spec_for(cpu)&.source&.name
  end

  def source_url(row, cpu) = row.spec_for(cpu)&.statement_url

  def tooltip_id(row, cpu) = "spec-source-#{row.spec_key}-#{cpu.slug}"

  # A figure read back out of the runs is not a vendor specification, so it
  # carries the same kind of provenance a score does: how many runs it came
  # from and how far they agreed.
  def sample_label(row, cpu)
    spec = row.spec_for(cpu)
    return if spec.nil? || spec.sample_count.blank?

    runs = "#{number_with_delimiter(spec.sample_count)} #{'run'.pluralize(spec.sample_count)}"
    return runs if spec.agreement_percent.blank?

    agreement = spec.agreement_percent.to_f
    return "#{runs} agree" if agreement >= 99.95

    "#{runs}, #{number_with_precision(agreement, precision: 0)}% agree"
  end
end
