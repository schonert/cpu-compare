# Page header: title, one-line explanation, and the Compare / Browse switch.
class MastheadComponent < ApplicationComponent
  MODES = [
    { key: "compare", label: "Compare" },
    { key: "browse", label: "Browse" }
  ].freeze

  def initialize(mode:, selected: [], version: nil)
    @mode = mode
    @selected = selected
    @version = version
  end

  attr_reader :mode, :selected, :version

  def path_for(key)
    query = { cpus: selected.join(",").presence, version: version }.compact
    key == "compare" ? compare_path(query) : cpus_path(query)
  end

  def current?(key) = key == mode

  # Segmented control: a solid ink pill marks the current view against the
  # recessed track. Inactive items are ghost buttons that fill on hover.
  def tab_classes(key)
    base = "rounded-md px-4 py-1.5 text-[13px] font-emphasis transition"
    current?(key) ? "#{base} bg-ink text-panel" : "#{base} text-ink-muted hover:bg-hover hover:text-ink"
  end
end
