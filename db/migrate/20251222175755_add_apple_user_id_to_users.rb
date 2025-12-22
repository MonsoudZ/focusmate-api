class AddAppleUserIdToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :users, :apple_user_id, :string
    add_index :users, :apple_user_id, unique: true, algorithm: :concurrently
  end
end
