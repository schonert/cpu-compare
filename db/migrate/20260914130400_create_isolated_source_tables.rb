# Sources that must never reach a published score, kept in their own tables so
# the separation is structural rather than a convention someone has to remember.
#
# Nothing in this migration is joined into `benchmark_scores`, and the scoring
# aggregator only ever reads `benchmark_submissions`.
class CreateIsolatedSourceTables < ActiveRecord::Migration[8.0]
  def change
    # OpenBenchmarking.org, if a CSV/XML export is ever added as a second
    # source. Deliberately a separate table with its own metric vocabulary: a
    # PTS result is a different protocol and cannot be averaged with a Blender
    # one, so there is no schema path that would let them merge.
    create_table :openbenchmarking_results do |t|
      t.references :source, null: false, foreign_key: true
      t.references :cpu, foreign_key: true
      t.string  :test_profile, null: false
      t.string  :test_version
      t.string  :metric_key, null: false
      t.string  :metric_unit, null: false
      t.boolean :higher_is_better, null: false
      t.string  :raw_device_name, null: false
      t.decimal :median, precision: 16, scale: 4, null: false
      t.integer :sample_count, null: false, default: 1
      t.string  :upstream_id
      t.datetime :retrieved_at, null: false
      t.timestamps
      t.index %i[test_profile test_version raw_device_name metric_key],
              unique: true, name: "index_obr_on_profile_device_metric"
    end

    # Commercially licensed data — PassMark's paid CSV is the case this exists
    # for. Rows carry the licence reference they were obtained under and are
    # flagged on display. Nothing here is ever blended into a score.
    create_table :licensed_benchmark_results do |t|
      t.references :source, null: false, foreign_key: true
      t.references :cpu, foreign_key: true
      t.string  :vendor_reference, null: false
      t.string  :cpu_name, null: false
      t.string  :metric_key, null: false
      t.string  :metric_unit
      t.decimal :value, precision: 16, scale: 4, null: false
      t.integer :sample_count
      # Required: a row without a licence reference has no business existing.
      t.string  :license_reference, null: false
      t.date    :license_expires_on
      t.datetime :retrieved_at, null: false
      t.timestamps
      t.index %i[source_id vendor_reference metric_key],
              unique: true, name: "index_licensed_on_source_ref_metric"
    end
  end
end
