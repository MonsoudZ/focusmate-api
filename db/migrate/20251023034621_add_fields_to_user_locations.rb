class AddFieldsToUserLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :user_locations, :source, :string unless column_exists?(:user_locations, :source)
    add_column :user_locations, :metadata, :jsonb, default: {} unless column_exists?(:user_locations, :metadata)
    add_column :user_locations, :deleted_at, :datetime unless column_exists?(:user_locations, :deleted_at)

    add_index :user_locations, :recorded_at unless index_exists?(:user_locations, :recorded_at)
    add_index :user_locations, :source unless index_exists?(:user_locations, :source)
    add_index :user_locations, :deleted_at unless index_exists?(:user_locations, :deleted_at)
  end
end
