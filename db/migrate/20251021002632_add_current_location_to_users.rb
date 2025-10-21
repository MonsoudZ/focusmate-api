class AddCurrentLocationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :current_latitude, :decimal
    add_column :users, :current_longitude, :decimal
  end
end
