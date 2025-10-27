class AddUserLocationsIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :user_locations, [:user_id, :recorded_at], algorithm: :concurrently, if_not_exists: true
    add_index :user_locations, :recorded_at, algorithm: :concurrently, if_not_exists: true
  end
end
