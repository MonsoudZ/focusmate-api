class EnhanceUsersForCoaching < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: 'client', null: false unless column_exists?(:users, :role)
    add_column :users, :fcm_token, :string unless column_exists?(:users, :fcm_token)
    add_column :users, :timezone, :string, default: 'UTC' unless column_exists?(:users, :timezone)
    add_column :users, :name, :string unless column_exists?(:users, :name)
    
    add_index :users, :role unless index_exists?(:users, :role)
    add_index :users, :fcm_token unless index_exists?(:users, :fcm_token)
  end
end