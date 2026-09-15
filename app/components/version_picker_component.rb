# Chooses which benchmark series is on screen.
#
# A picker rather than a merge: results from different majors are not
# comparable, so the site shows one series at a time instead of blending them
# into a single ranking.
class VersionPickerComponent < ApplicationComponent
  def initialize(versions:, current:, selected: [])
    @versions = versions
    @current = current
    @selected = selected
  end

  attr_reader :versions, :current, :selected

  def render? = versions.many?

  def current?(version) = current.present? && version.id == current.id

  def classes(version)
    ["rounded-full px-3 py-1 text-[12px] font-medium transition-colors",
     current?(version) ? "bg-ink text-panel" : "text-ink-muted hover:bg-sunken hover:text-ink"]
  end
end
