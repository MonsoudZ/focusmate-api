class AddMissingColumnsToDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :devices, :fcm_token, :string
    add_column :devices, :device_name, :string
    add_column :devices, :os_version, :string
    add_column :devices, :app_version, :string
    add_column :devices, :active, :boolean, default: true
    add_column :devices, :last_seen_at, :datetime

    add_index :devices, :fcm_token
    add_index :devices, :active
  end
end
