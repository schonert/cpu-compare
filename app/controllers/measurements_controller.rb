# The click-through the presentation contract requires: every displayed figure
# links here, and here shows the individual measurements it was computed from.
#
# No figure appears anywhere on the site that cannot be reached this way.
class MeasurementsController < ApplicationController
  PER_PAGE = 100

  def show
    @score = BenchmarkScore.includes(:cpu, :workload, :benchmark_version).find(params[:id])
    @page = [params[:page].to_i, 1].max

    submissions = @score.submissions.recent_first
    @total = submissions.count
    @submissions = submissions.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    # Shown so the sample count reconciles: these were measured and stored but
    # deliberately not aggregated, each with its reason.
    @excluded = BenchmarkSubmission
                .where(cpu_id: @score.cpu_id, benchmark_version_id: @score.benchmark_version_id,
                       workload_id: @score.workload_id, eligible: false)
                .group(:exclusion_reason).count
  end
end
