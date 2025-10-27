class AddDeviceConstraints < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :devices, [:user_id, :apns_token], unique: true, name: 'index_devices_on_user_id_and_apns_token', algorithm: :concurrently
    add_index :devices, [:user_id, :fcm_token], unique: true, name: 'index_devices_on_user_id_and_fcm_token', algorithm: :concurrently
    add_index :devices, :platform, algorithm: :concurrently
    add_check_constraint :devices, "platform IN ('ios','android')", name: 'devices_platform_enum', validate: false
  end
end
