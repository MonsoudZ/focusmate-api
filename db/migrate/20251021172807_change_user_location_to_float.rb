class ChangeUserLocationToFloat < ActiveRecord::Migration[8.0]
  def change
    change_column :users, :latitude, :float
    change_column :users, :longitude, :float
    change_column :users, :current_latitude, :float
    change_column :users, :current_longitude, :float
  end
end
