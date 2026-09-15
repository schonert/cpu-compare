# Chooses which benchmark series is on screen.
#
# A picker rather than a merge: results from different majors are not
# comparable, so the site shows one series at a time instead of blending them
# into a single ranking.
#
# Takes a path builder so browse stays on /processors and compare stays on
# /compare — the same series switch must not dump the user onto the other tab.
class VersionPickerComponent < ApplicationComponent
  def initialize(versions:, current:, path:)
    @versions = versions
    @current = current
    @path = path
  end

  attr_reader :versions, :current

  def render? = versions.many?

  def current?(version) = current.present? && version.id == current.id

  def path_for(version) = @path.call(version)

  def classes(version)
    ["rounded-full px-3 py-1 text-[12px] font-medium transition-colors",
     current?(version) ? "bg-ink text-panel" : "text-ink-muted hover:bg-sunken hover:text-ink"]
  end
end
