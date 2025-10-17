class AddLocationAndFcmToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :latitude, :decimal
    add_column :users, :longitude, :decimal
    add_column :users, :preferences, :jsonb
    add_column :users, :location_updated_at, :datetime
  end
end
