# A processor, its alias table, and per-field spec provenance.
#
# A CPU exists here because something measured it. Specifications are optional
# enrichment on top — Wikidata carries detailed specs for only a few hundred
# parts, so most of the catalogue has scores and no spec sheet, and the schema
# has to make that the normal case rather than an error.
class CreateCpus < ActiveRecord::Migration[8.0]
  def change
    create_table :cpus do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :vendor, null: false
      t.string :wikidata_qid

      # Denormalised for querying and sorting only. Every one of these is
      # materialised from a `cpu_specs` row, which holds the source, the deep
      # link to the exact statement and the date it was read.
      t.integer :cores
      t.integer :threads
      t.integer :base_clock_mhz
      t.integer :boost_clock_mhz
      t.integer :tdp_watts
      t.string  :socket
      t.decimal :lithography_nm, precision: 8, scale: 2
      t.decimal :launch_price_usd, precision: 10, scale: 2
      t.date    :released_on
      t.string  :microarchitecture

      t.timestamps
      t.index :slug, unique: true
      t.index :wikidata_qid, unique: true
      t.index :vendor
      t.index :name
    end

    # Every raw device string ever seen, and what it was resolved to. Unmatched
    # strings are kept with a null cpu_id rather than dropped, so normalisation
    # coverage is measurable instead of invisible.
    create_table :cpu_aliases do |t|
      t.references :cpu, foreign_key: true
      t.string  :raw_name, null: false
      t.string  :normalized_name, null: false
      t.string  :match_method, null: false
      t.integer :submission_count, null: false, default: 0
      t.timestamps
      t.index :raw_name, unique: true
      t.index :normalized_name
    end

    # One sourced fact about one CPU. Two sources may disagree; both are kept
    # and `precedence` decides which is materialised onto `cpus`.
    create_table :cpu_specs do |t|
      t.references :cpu, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      t.string  :attribute, null: false
      t.decimal :value_numeric, precision: 16, scale: 4
      t.string  :value_text
      t.date    :value_date
      t.string  :unit
      t.string  :statement_url
      t.datetime :retrieved_at, null: false
      t.integer :precedence, null: false, default: 0
      t.timestamps
      t.index %i[cpu_id attribute source_id], unique: true, name: "index_cpu_specs_on_cpu_attribute_source"
    end
  end
end
