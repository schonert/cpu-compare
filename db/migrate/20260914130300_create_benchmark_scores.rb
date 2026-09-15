# The aggregate: exactly one row per (cpu, benchmark version, workload, metric).
#
# There is deliberately no table for a blended cross-workload number. Every row
# here is traceable to the submissions that produced it, and carries the spread
# and the sample count so the figure can be read with its uncertainty rather
# than on its own.
class CreateBenchmarkScores < ActiveRecord::Migration[8.0]
  def change
    create_table :benchmark_scores do |t|
      t.references :cpu, null: false, foreign_key: true
      t.references :benchmark_version, null: false, foreign_key: true
      t.references :workload, null: false, foreign_key: true

      t.string  :metric_key, null: false
      t.string  :metric_unit, null: false
      t.boolean :higher_is_better, null: false

      t.integer :sample_count, null: false
      t.decimal :median, precision: 16, scale: 4, null: false
      t.decimal :q1, precision: 16, scale: 4
      t.decimal :q3, precision: 16, scale: 4
      t.decimal :iqr, precision: 16, scale: 4
      t.decimal :minimum, precision: 16, scale: 4
      t.decimal :maximum, precision: 16, scale: 4

      # Below the threshold the figure is kept but not displayed. Storing the
      # threshold that was in force means an old score stays explainable after
      # the config changes.
      t.boolean :suppressed, null: false, default: false
      t.integer :min_samples, null: false
      t.integer :scoring_config_version, null: false

      # "Last updated" for the presentation contract: when the newest underlying
      # measurement was taken, and when this aggregate was last recomputed.
      t.datetime :measured_from
      t.datetime :measured_to
      t.datetime :computed_at, null: false

      t.references :ingest_run, foreign_key: true
      t.timestamps

      t.index %i[cpu_id benchmark_version_id workload_id metric_key],
              unique: true, name: "index_scores_on_score_key"
      t.index %i[benchmark_version_id workload_id suppressed median],
              name: "index_scores_on_ranking"
    end
  end
end
