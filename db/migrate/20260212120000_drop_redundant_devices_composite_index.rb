# frozen_string_literal: true

class DropRedundantDevicesCompositeIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # The unique index on apns_token alone (index_devices_on_apns_token) already
    # guarantees uniqueness. The composite (user_id, apns_token) index is redundant
    # because apns_token is globally unique — no two users can share the same token.
    remove_index :devices, [ :user_id, :apns_token ],
                 name: "index_devices_on_user_id_and_apns_token",
                 algorithm: :concurrently
  end
end
