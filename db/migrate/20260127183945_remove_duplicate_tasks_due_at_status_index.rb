# frozen_string_literal: true

class RemoveDuplicateTasksDueAtStatusIndex < ActiveRecord::Migration[7.0]
  def up
    remove_index :tasks, name: :index_tasks_on_due_at_status, if_exists: true
  end

  def down
    add_index :tasks, [:due_at, :status], name: :index_tasks_on_due_at_status
  end
end
