module BlenderOpenData
  # Ingests a snapshot into benchmark_submissions.
  #
  # Idempotent by construction. Every measurement is keyed on
  # (upstream_id, entry_index), which upstream assigns and never reuses, so
  # re-running against a newer snapshot updates what is already stored and
  # inserts only what is new. Nothing is deleted: a measurement that drops out
  # of a later snapshot keeps its row and its last_seen_run, so history survives
  # the refresh.
  #
  # Aggregation is deliberately NOT done here. This pass only records what was
  # measured; Scoring::Aggregator turns it into figures.
  class Importer
    BATCH = 2_000

    # Immutable measurement data is written once; only these change on a
    # re-import, so first_seen_run and the measurement itself are preserved.
    UPDATE_ON_CONFLICT = %i[
      cpu_id eligible exclusion_reason last_seen_run_id updated_at
    ].freeze

    def self.call(...) = new(...).call

    def initialize(snapshot: Snapshot.new, config: Scoring::Config.current, logger: Rails.logger)
      @snapshot = snapshot
      @config = config
      @logger = logger
    end

    attr_reader :snapshot, :config

    def call
      Catalog.install!
      run = start_run

      @source_id = Source[Source::BLENDER_OPEN_DATA].id
      @versions = BenchmarkVersion.joins(:benchmark_suite)
                                 .where(benchmark_suites: { key: BenchmarkSuite::BLENDER })
                                 .to_h { |v| [v.series, v.id] }
      @workloads = Workload.joins(:benchmark_suite)
                           .where(benchmark_suites: { key: BenchmarkSuite::BLENDER })
                           .to_h { |w| [w.key, w.id] }
      @resolver = Cpus::Resolver.new
      @run = run
      @buffer = []
      @seen = 0
      @skipped = 0
      @written = 0

      snapshot.each_record do |record|
        Entry.each_in(record) { |entry| absorb(entry) }
      end
      flush!
      @resolver.flush!

      before = run.submissions_created
      run.succeed!(
        records_seen: @seen,
        records_skipped: @skipped,
        submissions_created: @written,
        cpus_created: @resolver.cpus_created,
        details: {
          "unmatched_aliases" => CpuAlias.unmatched.count,
          "resolved_aliases" => CpuAlias.where.not(cpu_id: nil).count,
          "eligible" => BenchmarkSubmission.eligible.count
        }
      )
      run
    rescue StandardError => e
      run&.fail!(e.message)
      raise
    end

    private

    def start_run
      # Verified rather than assumed: if upstream ever changes the licence, the
      # ingest stops instead of quietly republishing something we may not.
      unless snapshot.cc0?
        raise "snapshot #{snapshot.label} is not CC0 — refusing to ingest"
      end

      IngestRun.create!(
        source_key: Source::BLENDER_OPEN_DATA,
        kind: IngestRun::BLENDER_SNAPSHOT,
        status: IngestRun::RUNNING,
        started_at: Time.current,
        snapshot_label: snapshot.label,
        snapshot_url: snapshot.url,
        snapshot_sha256: snapshot.sha256,
        snapshot_bytes: snapshot.bytes,
        snapshot_taken_at: snapshot.taken_at
      )
    end

    def absorb(entry)
      @seen += 1
      version_id = @versions[entry.series]
      workload_id = @workloads[entry.scene_key]

      # A series or scene we have not declared is skipped loudly rather than
      # invented: a new major version is a decision, not a data event.
      if version_id.nil? || workload_id.nil?
        @skipped += 1
        return
      end

      resolution = @resolver.call(entry.raw_device_name)
      reason = exclusion_reason(entry, resolution)

      @buffer << {
        source_id: @source_id,
        benchmark_version_id: version_id,
        workload_id: workload_id,
        cpu_id: resolution.cpu_id,
        upstream_id: entry.upstream_id,
        entry_index: entry.entry_index,
        raw_device_name: entry.raw_device_name,
        value: entry.value,
        metric_key: entry.metric_key,
        samples_per_minute: entry.samples_per_minute,
        render_time_seconds: entry.render_time_seconds,
        total_render_time_seconds: entry.total_render_time_seconds,
        number_of_samples: entry.number_of_samples,
        time_limit_seconds: entry.time_limit_seconds,
        device_peak_memory_mb: entry.device_peak_memory_mb,
        device_threads: entry.device_threads,
        system_threads: entry.system_threads,
        system_cores: entry.system_cores,
        sockets: entry.sockets,
        operating_system: entry.operating_system,
        benchmark_build: entry.build,
        launcher_version: entry.launcher_version,
        script_version: entry.script_version,
        scene_checksum: entry.scene_checksum,
        schema_version: entry.schema_version,
        measured_at: entry.measured_at,
        eligible: reason.nil?,
        exclusion_reason: reason,
        first_seen_run_id: @run.id,
        last_seen_run_id: @run.id
      }

      flush! if @buffer.size >= BATCH
    end

    # Why a stored measurement is not aggregated. Each branch maps to a rule in
    # config/scoring.yml, so the published methodology and the data agree.
    def exclusion_reason(entry, resolution)
      return BenchmarkSubmission::CRASHED if config.exclude_crashed? && entry.crashed?
      # A dual-socket machine is a different system, not the same processor.
      if config.single_socket_only? && entry.sockets.present? && entry.sockets != 1
        return BenchmarkSubmission::MULTI_SOCKET
      end
      # A deliberately thread-limited run measures a configuration, not a chip.
      if config.exclude_thread_restricted? && entry.device_threads.present? &&
         entry.system_threads.present? && entry.device_threads < entry.system_threads
        return BenchmarkSubmission::THREAD_RESTRICTED
      end
      return BenchmarkSubmission::UNMATCHED_CPU unless resolution.matched?

      nil
    end

    def flush!
      return if @buffer.empty?

      BenchmarkSubmission.upsert_all(
        @buffer,
        unique_by: :index_submissions_on_upstream,
        update_only: UPDATE_ON_CONFLICT - %i[updated_at],
        record_timestamps: true
      )
      @written += @buffer.size
      @buffer.clear
      @logger.info("[blender] #{@written} submissions written") if (@written % 100_000).zero?
    end
  end
end
