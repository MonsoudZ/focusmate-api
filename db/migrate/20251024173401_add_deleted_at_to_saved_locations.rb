class AddDeletedAtToSavedLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :saved_locations, :deleted_at, :datetime
  end
end
