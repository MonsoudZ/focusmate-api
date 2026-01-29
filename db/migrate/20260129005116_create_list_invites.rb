class CreateListInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :list_invites do |t|
      t.string :code, null: false
      t.references :list, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :role, null: false, default: "viewer"
      t.datetime :expires_at
      t.integer :max_uses
      t.integer :uses_count, null: false, default: 0

      t.timestamps
    end
    add_index :list_invites, :code, unique: true
  end
end
