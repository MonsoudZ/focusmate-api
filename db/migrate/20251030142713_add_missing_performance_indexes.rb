class AddMissingPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Add index for task queries by assignee and status
    add_index :tasks, [:assigned_to_id, :status],
              name: 'index_tasks_on_assigned_to_status',
              if_not_exists: true,
              algorithm: :concurrently

    # Add index for completed task lookups by creator
    add_index :tasks, [:creator_id, :completed_at],
              name: 'index_tasks_on_creator_completed_at',
              if_not_exists: true,
              algorithm: :concurrently

    # Add index for user location history (created_at for sorting)
    add_index :user_locations, [:user_id, :created_at],
              name: 'index_user_locations_on_user_created_at',
              if_not_exists: true,
              algorithm: :concurrently

    # Add index for list share status queries
    add_index :list_shares, [:list_id, :status],
              name: 'index_list_shares_on_list_status',
              if_not_exists: true,
              algorithm: :concurrently
  end
end
