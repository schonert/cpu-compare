# The provenance line that travels with every measured figure: how many runs
# it is a median of, the spread, which benchmark version produced it, when it
# was last measured, and where it came from.
#
# Split out from FigureComponent so a caller can place the figure and its
# provenance separately without either being able to render the number on its
# own.
class FigureMetaComponent < ApplicationComponent
  def initialize(score:, show_source: true)
    @score = score
    @show_source = show_source
  end

  attr_reader :score

  def items
    [
      "#{number_with_delimiter(score.sample_count)} #{'run'.pluralize(score.sample_count)}",
      spread_label,
      score.benchmark_version.label,
      updated_label,
      (source_name if @show_source)
    ].compact
  end

  # Published alongside the median because a median on its own invites more
  # confidence than a public benchmark firehose deserves.
  def spread_label
    return if score.spread.nil? || score.spread.zero?

    "±#{number_with_precision(score.spread, precision: score.spread < 10 ? 1 : 0)} IQR/2"
  end

  def updated_label
    date = score.last_updated_at
    return if date.nil?

    "to #{date.utc.strftime('%b %Y')}"
  end

  def source_name = score.benchmark_version.benchmark_suite.source.name

  def call
    tag.span(class: "eyebrow flex flex-wrap items-center gap-x-2 gap-y-0.5 text-ink-faint") do
      safe_join(items.map { |item| tag.span(item) })
    end
  end
end
