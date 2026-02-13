# frozen_string_literal: true

# The single-column index on devices.fcm_token is redundant — the composite
# unique index (user_id, fcm_token) already exists and covers the uniqueness
# constraint. The single index is never used standalone.
class DropRedundantDevicesFcmTokenIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :devices, column: :fcm_token, name: "index_devices_on_fcm_token", algorithm: :concurrently, if_exists: true
  end
end
