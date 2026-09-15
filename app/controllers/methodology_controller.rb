# Publishes the rules. config/scoring.yml is rendered here verbatim, so the
# weights and thresholds the site runs on are the ones the public can read —
# which is the condition attached to ever adding a composite.
class MethodologyController < ApplicationController
  def show
    @config = Scoring::Config.current
    @sources = Source.order(:licensed, :name)
    @suite = BenchmarkSuite.blender
    @versions = BenchmarkVersion.ordered.includes(:benchmark_suite)
    @runs = IngestRun.recent.limit(8)
    @coverage = {
      processors: Cpu.count,
      displayable: Cpu.scored.count,
      submissions: BenchmarkSubmission.count,
      eligible: BenchmarkSubmission.eligible.count,
      scores: BenchmarkScore.count,
      suppressed: BenchmarkScore.where(suppressed: true).count,
      unmatched_aliases: CpuAlias.unmatched.count,
      exclusions: BenchmarkSubmission.where.not(exclusion_reason: nil).group(:exclusion_reason).count
    }
  end
end
