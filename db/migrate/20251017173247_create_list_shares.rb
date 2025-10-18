class CreateListShares < ActiveRecord::Migration[8.0]
  def change
    create_table :list_shares do |t|
      t.references :list, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :permissions, default: {}
      t.boolean :can_view, default: true
      t.boolean :can_edit, default: false
      t.boolean :can_add_items, default: false
      t.boolean :can_delete_items, default: false
      t.boolean :receive_notifications, default: true

      t.timestamps
    end

    add_index :list_shares, [ :list_id, :user_id ], unique: true
    add_index :list_shares, :permissions, using: :gin
  end
end
