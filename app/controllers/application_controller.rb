class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_navigation_state

  private

  # Both screens share the selection and the benchmark series, and both read
  # them from the query string rather than the session, so every view is
  # shareable and means the same thing to whoever opens it.
  def set_navigation_state
    @selected_slugs = Comparison.slugs_from(params[:cpus])
    @mode = controller_name == "cpus" ? "browse" : "compare"
  end
end
