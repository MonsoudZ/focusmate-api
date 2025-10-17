class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :title
      t.text :note
      t.datetime :due_at
      t.integer :status
      t.boolean :strict_mode
      t.references :list, null: false, foreign_key: true

      t.timestamps
    end
  end
end
