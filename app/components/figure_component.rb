# One measured figure, with everything the presentation contract requires
# attached to it: the raw value and its units, the sample count, the source,
# the benchmark version, and the date — plus a link through to the individual
# measurements it was computed from.
#
# Every benchmark number rendered anywhere on the site goes through this
# component or through the value/meta pair it is built from. That is the
# mechanism by which "no figure appears that can't be traced" is true rather
# than merely intended.
class FigureComponent < ApplicationComponent
  def initialize(score:, size: :md, show_source: true)
    @score = score
    @size = size
    @show_source = show_source
  end

  attr_reader :score

  def value = score_value(score)
  def show_source? = @show_source

  def sample_label
    "#{number_with_delimiter(score.sample_count)} #{'run'.pluralize(score.sample_count)}"
  end

  def value_classes
    ["figure font-semibold leading-none text-ink", @size == :lg ? "text-2xl" : "text-sm"]
  end

  def measurements_path = helpers.measurements_path(score)
end
