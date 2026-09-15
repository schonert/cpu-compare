# Base class for every component, so shared helpers are available everywhere.
class ApplicationComponent < ViewComponent::Base
  # Components render outside the view context, so Turbo's tag helpers have to
  # be mixed in explicitly.
  include Turbo::FramesHelper

  delegate :compare_path_with, :compare_path_without, :compare_path_for_version,
           :vendor_accent, :vendor_ink, :format_metric, :score_value, to: :helpers
end
