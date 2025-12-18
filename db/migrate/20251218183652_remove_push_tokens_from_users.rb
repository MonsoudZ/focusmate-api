# frozen_string_literal: true

class RemovePushTokensFromUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :users, :device_token, :string if column_exists?(:users, :device_token)
      remove_column :users, :fcm_token, :string if column_exists?(:users, :fcm_token)
    end
  end
end
