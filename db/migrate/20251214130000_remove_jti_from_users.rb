class RemoveJtiFromUsers < ActiveRecord::Migration[8.0]
  def change
    # Remove the users.jti index/column if they exist. This was previously used
    # for custom JWT handling but is now redundant with Devise-JWT's denylist.
    remove_index :users, :jti if index_exists?(:users, :jti)

    if column_exists?(:users, :jti)
      safety_assured { remove_column :users, :jti, :string }
    end
  end
end
