class CreateNudges < ActiveRecord::Migration[8.0]
  def change
    create_table :nudges do |t|
      t.references :task, null: false, foreign_key: true
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :nudges, [:task_id, :from_user_id, :created_at]
  end
end