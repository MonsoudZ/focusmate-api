# frozen_string_literal: true

class AddDashboardIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Indexes for dashboard queries
    add_index :tasks, [ :list_id, :updated_at ], algorithm: :concurrently, if_not_exists: true
    add_index :tasks, [ :due_at, :completed_at ], algorithm: :concurrently, if_not_exists: true
    add_index :tasks, [ :completed_at ], algorithm: :concurrently, if_not_exists: true
    add_index :task_events, [ :created_at ], algorithm: :concurrently, if_not_exists: true
    add_index :task_events, [ :task_id, :created_at ], algorithm: :concurrently, if_not_exists: true

    # Index for time series queries
    add_index :tasks, [ :completed_at, :list_id ], algorithm: :concurrently, if_not_exists: true
  end
end
