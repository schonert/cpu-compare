module Scoring
  # Turns raw submissions into one figure per
  # (cpu, benchmark version, workload, metric).
  #
  # The median, not the mean. Open Data is a public firehose: the same chip
  # appears throttled, virtualised and background-loaded, so the distribution
  # has a long low tail. On the 5950X/monster group the minimum is 16 samples a
  # minute against a median near 200 — a mean would track the junk.
  #
  # Nothing here crosses a benchmark version or a workload, and there is no
  # code path that produces a blended number: the grouping key is the scoring
  # key, so an opaque composite is not expressible.
  class Aggregator
    # CPUs per chunk. Bounds memory while keeping every group whole — a CPU's
    # rows never straddle two chunks, so a median is never computed on half a
    # group.
    CHUNK = 250

    def self.call(...) = new(...).call

    def initialize(config: Config.current, logger: Rails.logger)
      @config = config
      @logger = logger
    end

    attr_reader :config

    def call
      run = IngestRun.create!(
        source_key: Source::BLENDER_OPEN_DATA, kind: IngestRun::SCORING,
        status: IngestRun::RUNNING, started_at: Time.current
      )

      @versions = BenchmarkVersion.all.index_by(&:id)
      @computed_at = Time.current
      @run = run
      written = 0

      cpu_ids = BenchmarkSubmission.eligible.distinct.pluck(:cpu_id)
      cpu_ids.each_slice(CHUNK) do |slice|
        written += write_chunk(slice)
      end

      removed = prune_orphans
      suppressed = BenchmarkScore.where(suppressed: true).count

      run.succeed!(
        scores_written: written,
        details: {
          "scores_total" => BenchmarkScore.count,
          "suppressed" => suppressed,
          "displayable" => BenchmarkScore.displayable.count,
          "removed" => removed,
          "min_samples" => config.min_samples,
          "scoring_config_version" => config.version
        }
      )
      run
    rescue StandardError => e
      run&.fail!(e.message)
      raise
    end

    private

    # Ordering by value in SQL means each group arrives already sorted, so the
    # quantiles are a walk rather than a re-sort.
    def write_chunk(cpu_ids)
      rows = BenchmarkSubmission
             .eligible
             .where(cpu_id: cpu_ids)
             .order(:cpu_id, :benchmark_version_id, :workload_id, :value)
             .pluck(:cpu_id, :benchmark_version_id, :workload_id, :value, :measured_at)

      scores = []
      group = nil
      values = []
      first_at = nil
      last_at = nil

      flush = lambda do
        scores << build(group, values, first_at, last_at) if group
      end

      rows.each do |cpu_id, version_id, workload_id, value, measured_at|
        key = [cpu_id, version_id, workload_id]
        if key != group
          flush.call
          group = key
          values = []
          first_at = last_at = nil
        end
        values << value
        first_at = measured_at if measured_at && (first_at.nil? || measured_at < first_at)
        last_at = measured_at if measured_at && (last_at.nil? || measured_at > last_at)
      end
      flush.call

      return 0 if scores.empty?

      BenchmarkScore.upsert_all(scores, unique_by: :index_scores_on_score_key,
                                        record_timestamps: true)
      scores.size
    end

    def build((cpu_id, version_id, workload_id), values, first_at, last_at)
      version = @versions.fetch(version_id)
      q1 = Quantiles.q1(values)
      q3 = Quantiles.q3(values)

      {
        cpu_id: cpu_id,
        benchmark_version_id: version_id,
        workload_id: workload_id,
        metric_key: version.metric_key,
        metric_unit: version.metric_unit,
        higher_is_better: version.higher_is_better,
        sample_count: values.size,
        median: round(Quantiles.median(values)),
        q1: round(q1),
        q3: round(q3),
        iqr: round(q3 && q1 && (q3 - q1)),
        minimum: round(values.first),
        maximum: round(values.last),
        # Kept rather than dropped: a thin figure is still evidence, it just
        # must not be displayed as though it were solid.
        suppressed: values.size < config.min_samples,
        min_samples: config.min_samples,
        scoring_config_version: config.version,
        measured_from: first_at,
        measured_to: last_at,
        computed_at: @computed_at,
        ingest_run_id: @run.id
      }
    end

    def round(value) = value&.to_f&.round(4)

    # A score whose submissions have all become ineligible — an alias remapped
    # by hand, say — must not linger as a figure with no evidence behind it.
    def prune_orphans
      BenchmarkScore.where.not(
        BenchmarkSubmission.eligible
          .where("benchmark_submissions.cpu_id = benchmark_scores.cpu_id")
          .where("benchmark_submissions.benchmark_version_id = benchmark_scores.benchmark_version_id")
          .where("benchmark_submissions.workload_id = benchmark_scores.workload_id")
          .arel.exists
      ).delete_all
    end
  end
end
