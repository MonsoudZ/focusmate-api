class RemoveStaleCounterCachesFromUsersAndLists < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :users, :lists_count, :integer, default: 0, null: false }
    safety_assured { remove_column :users, :devices_count, :integer, default: 0, null: false }
    safety_assured { remove_column :lists, :list_shares_count, :integer, default: 0, null: false }
  end
end
