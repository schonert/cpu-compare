# `attribute` is defined by Active Record itself, so a column of that name
# raises DangerousAttributeError. `spec_key` says the same thing and does not
# collide.
class RenameCpuSpecAttribute < ActiveRecord::Migration[8.0]
  def change
    rename_column :cpu_specs, :attribute, :spec_key
  end
end
