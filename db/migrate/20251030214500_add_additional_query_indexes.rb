# frozen_string_literal: true

class AddAdditionalQueryIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Tasks table - frequently queried patterns
    # Tasks by list and parent (for subtask queries)
    add_index :tasks, [ :list_id, :parent_task_id ], name: "index_tasks_on_list_and_parent",
              algorithm: :concurrently, if_not_exists: true

    # Tasks by list and deleted_at (for active tasks queries)
    add_index :tasks, [ :list_id, :deleted_at ], name: "index_tasks_on_list_and_deleted",
              algorithm: :concurrently, if_not_exists: true

    # Tasks by status and completed_at (for overdue queries)
    add_index :tasks, [ :status, :completed_at ], name: "index_tasks_on_status_and_completed",
              algorithm: :concurrently, if_not_exists: true

    # Lists table - frequently filtered by user and deleted status
    add_index :lists, [ :user_id, :visibility ], name: "index_lists_on_user_and_visibility",
              algorithm: :concurrently, if_not_exists: true

    # List shares - filtered by user and status together
    add_index :list_shares, [ :user_id, :status ], name: "index_list_shares_on_user_and_status",
              algorithm: :concurrently, if_not_exists: true

    # Notification logs - filtered by user, delivered status, and read status together
    add_index :notification_logs, [ :user_id, :delivered ], name: "index_notification_logs_on_user_and_delivered",
              algorithm: :concurrently, if_not_exists: true

    # Task events - filtered by task and kind together
    add_index :task_events, [ :task_id, :kind ], name: "index_task_events_on_task_and_kind",
              algorithm: :concurrently, if_not_exists: true

    # Daily summaries - filtered by relationship and sent status
    add_index :daily_summaries, [ :coaching_relationship_id, :sent ],
              name: "index_daily_summaries_on_relationship_and_sent",
              algorithm: :concurrently, if_not_exists: true

    # Memberships - list_id and role composite
    add_index :memberships, [ :list_id, :role ], name: "index_memberships_on_list_and_role",
              algorithm: :concurrently, if_not_exists: true

    # Saved locations - search by name and address (supports ILIKE queries)
    add_index :saved_locations, :name, name: "index_saved_locations_on_name",
              algorithm: :concurrently, if_not_exists: true
    add_index :saved_locations, :address, name: "index_saved_locations_on_address",
              algorithm: :concurrently, if_not_exists: true

    # User locations - filtered by user and deleted_at
    add_index :user_locations, [ :user_id, :deleted_at ],
              name: "index_user_locations_on_user_and_deleted",
              algorithm: :concurrently, if_not_exists: true
  end
end
