# frozen_string_literal: true

class AddIndexToTasksAssignedToId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :tasks, :assigned_to_id, algorithm: :concurrently, if_not_exists: true
  end
end
