class CreateTaskEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :task_events do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :kind
      t.text :reason
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
