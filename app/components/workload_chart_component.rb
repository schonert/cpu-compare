# One workload drawn as a segmented bar chart, one bar per compared CPU.
#
# Names live in a fixed first column rather than on the bars, so every bar
# starts at the same x-position and lengths read against each other directly.
# That frees the bars from carrying identity, so they stay monochrome for
# every row and the leader is marked by weight rather than color.
#
# Each workload gets its own chart. They are never averaged together: the whole
# point of showing them side by side is that a chip can win one and lose
# another.
class WorkloadChartComponent < ApplicationComponent
  delegate :measurements_path, to: :helpers

  def initialize(chart:)
    @chart = chart
  end

  attr_reader :chart

  def render? = chart.render?

  def bars = chart.bars
  def workload = chart.workload

  def tick_ink(_bar) = "text-ink"

  def value_classes(bar)
    ["figure shrink-0 text-end text-sm leading-none",
     bar.best ? "font-strong text-ink" : "font-medium text-ink"]
  end

  def name_classes(bar)
    ["truncate text-[13px] leading-tight",
     bar.best ? "font-strong text-ink" : "font-normal text-ink-muted"]
  end
end
