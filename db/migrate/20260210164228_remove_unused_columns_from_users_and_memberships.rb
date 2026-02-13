class RemoveUnusedColumnsFromUsersAndMemberships < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :users, :remember_created_at, :datetime
      remove_column :users, :latitude, :float
      remove_column :users, :longitude, :float
      remove_column :users, :current_latitude, :float
      remove_column :users, :current_longitude, :float
      remove_column :users, :location_updated_at, :datetime
      remove_column :users, :preferences, :jsonb

      remove_column :memberships, :can_add_items, :boolean, default: true
      remove_column :memberships, :receive_overdue_alerts, :boolean, default: true
    end
  end
end
