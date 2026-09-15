# Sources, benchmarks, versions and workloads: the vocabulary every measurement
# is filed under. Nothing may be stored without pointing at a row in `sources`,
# which is where the licence — and therefore redistributability — is asserted.
class CreateProvenanceTables < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.string  :key, null: false
      t.string  :name, null: false
      t.string  :url
      t.string  :terms_url
      t.string  :license, null: false
      t.string  :license_url
      # Whether we may republish the values themselves. Everything the site
      # renders must come from a source where this is true.
      t.boolean :redistributable, null: false, default: false
      # Whether the source needs a paid licence. Licensed data lives in its own
      # table and is never aggregated with the rest.
      t.boolean :licensed, null: false, default: false
      t.text    :notes
      t.timestamps
      t.index :key, unique: true
    end

    create_table :benchmark_suites do |t|
      t.references :source, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      # The named measurement protocol. Every number on the site traces back to
      # one of these, by requirement.
      t.text   :protocol, null: false
      t.string :protocol_url
      t.timestamps
      t.index :key, unique: true
    end

    # One row per major benchmark series. The series — not the exact build — is
    # the aggregation unit, because results are only comparable within one.
    # Blender 4.x and 5.x are separate rows and are never combined.
    create_table :benchmark_versions do |t|
      t.references :benchmark_suite, null: false, foreign_key: true
      t.string  :series, null: false
      t.string  :label, null: false
      t.string  :metric_key, null: false
      t.string  :metric_unit, null: false
      t.boolean :higher_is_better, null: false
      t.text    :notes
      t.timestamps
      t.index %i[benchmark_suite_id series], unique: true
    end

    # A scene or workload. Scored separately and shown side by side, never
    # collapsed into one headline figure.
    create_table :workloads do |t|
      t.references :benchmark_suite, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.text   :description
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index %i[benchmark_suite_id key], unique: true
    end
  end
end
