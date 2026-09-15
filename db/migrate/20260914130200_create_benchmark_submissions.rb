# The raw measurements: one row per (upstream submission, scene). This is the
# evidence layer — a ranking row on the site is explainable by clicking through
# to exactly these rows, so nothing here is ever summarised away or deleted.
#
# Ingest is idempotent on (upstream_id, entry_index): re-running against a newer
# snapshot updates what is already here and inserts what is new, and the
# first/last seen run references preserve the history of when each measurement
# appeared.
class CreateBenchmarkSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :benchmark_submissions do |t|
      t.references :source, null: false, foreign_key: true
      t.references :benchmark_version, null: false, foreign_key: true
      t.references :workload, null: false, foreign_key: true
      # Null until the device string is resolved. An unmatched submission is
      # still stored; it simply cannot be aggregated yet.
      t.references :cpu, foreign_key: true

      t.string  :upstream_id, null: false
      t.integer :entry_index, null: false, default: 0
      t.string  :raw_device_name, null: false

      # The canonical metric for this series, copied here so aggregation reads
      # one column regardless of which series a row belongs to.
      t.decimal :value, precision: 16, scale: 4, null: false
      t.string  :metric_key, null: false

      # Everything upstream reported, kept for traceability.
      t.decimal :samples_per_minute, precision: 16, scale: 4
      t.decimal :render_time_seconds, precision: 16, scale: 4
      t.decimal :total_render_time_seconds, precision: 16, scale: 4
      t.integer :number_of_samples
      t.integer :time_limit_seconds
      t.decimal :device_peak_memory_mb, precision: 14, scale: 2

      t.integer :device_threads
      t.integer :system_threads
      t.integer :system_cores
      t.integer :sockets
      t.string  :operating_system

      # The exact build, not just the series — "5.2.0" inside series 5.
      t.string  :benchmark_build, null: false
      t.string  :launcher_version
      t.string  :script_version
      t.string  :scene_checksum
      t.string  :schema_version

      t.datetime :measured_at

      # Why a row is or is not aggregated, recorded per row so a sample count
      # can always be reconciled against the raw data.
      t.boolean :eligible, null: false, default: true
      t.string  :exclusion_reason

      t.references :first_seen_run, foreign_key: { to_table: :ingest_runs }
      t.references :last_seen_run, foreign_key: { to_table: :ingest_runs }

      t.timestamps

      t.index %i[upstream_id entry_index], unique: true, name: "index_submissions_on_upstream"
      # Drives aggregation and the click-through from a score to its evidence.
      t.index %i[cpu_id benchmark_version_id workload_id eligible],
              name: "index_submissions_on_score_key"
      t.index :raw_device_name
      t.index :measured_at
    end
  end
end
