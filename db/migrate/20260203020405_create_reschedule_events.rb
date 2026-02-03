# frozen_string_literal: true

class CreateRescheduleEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :reschedule_events do |t|
      t.references :task, null: false, foreign_key: true, index: true
      t.datetime :previous_due_at
      t.datetime :new_due_at
      t.string :reason, null: false

      t.timestamps
    end

    add_index :reschedule_events, [:task_id, :created_at]
  end
end
