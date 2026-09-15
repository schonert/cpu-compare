# A spec can now be derived from the measurements rather than stated by a
# source, so a spec row needs the same kind of provenance a score carries: how
# many runs it was read from, and how much they agreed.
#
# Null for a stated spec — Wikidata does not have a sample count.
class AddSampleProvenanceToCpuSpecs < ActiveRecord::Migration[8.0]
  def change
    add_column :cpu_specs, :sample_count, :integer
    add_column :cpu_specs, :agreement_percent, :decimal, precision: 5, scale: 1
  end
end
