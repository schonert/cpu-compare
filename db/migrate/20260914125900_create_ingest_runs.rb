# One row per ingest or scoring pass. Runs are never overwritten, so the
# history of what was imported, from which snapshot, and what changed survives
# every re-run against a newer snapshot.
class CreateIngestRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :ingest_runs do |t|
      t.string :source_key, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "running"

      # Identifies the exact input. The checksum is what makes a re-run
      # verifiable: the same snapshot ingested twice is a no-op.
      t.string  :snapshot_label
      t.string  :snapshot_url
      t.string  :snapshot_sha256
      t.bigint  :snapshot_bytes
      t.datetime :snapshot_taken_at

      t.datetime :started_at
      t.datetime :finished_at

      t.integer :records_seen, null: false, default: 0
      t.integer :records_skipped, null: false, default: 0
      t.integer :submissions_created, null: false, default: 0
      t.integer :submissions_updated, null: false, default: 0
      t.integer :cpus_created, null: false, default: 0
      t.integer :specs_written, null: false, default: 0
      t.integer :scores_written, null: false, default: 0

      t.text :error_message
      t.text :details

      t.timestamps
      t.index %i[source_key kind started_at], name: "index_ingest_runs_on_source_kind_time"
      t.index :snapshot_sha256
    end
  end
end
