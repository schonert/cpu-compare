# Type-ahead search over the catalogue. The input posts to a Turbo Frame, so
# results are rendered by Rails and no CPU data is duplicated into JavaScript.
class CpuSearchComponent < ApplicationComponent
  FRAME_ID = "cpu_search_results".freeze

  def initialize(selected:, version:, disabled: false)
    @selected = selected
    @version = version
    @disabled = disabled
  end

  attr_reader :selected, :version

  def disabled? = @disabled

  def placeholder = "Search processors"
end
