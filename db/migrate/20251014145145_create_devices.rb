class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :apns_token, null: false
      t.string :platform, null: false, default: "ios"
      t.string :bundle_id

      t.timestamps
    end
    add_index :devices, :apns_token, unique: true
  end
end
