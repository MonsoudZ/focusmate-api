class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for dashboard performance
    add_index :task_events, [ :created_at, :task_id ], name: 'index_task_events_on_created_at_task_id' unless index_exists?(:task_events, [ :created_at, :task_id ], name: 'index_task_events_on_created_at_task_id')
    add_index :task_events, [ :task_id, :created_at ], name: 'index_task_events_on_task_created_at' unless index_exists?(:task_events, [ :task_id, :created_at ], name: 'index_task_events_on_task_created_at')

    # Add indexes for task queries
    add_index :tasks, [ :due_at, :status ], name: 'index_tasks_on_due_at_status' unless index_exists?(:tasks, [ :due_at, :status ], name: 'index_tasks_on_due_at_status')
    add_index :tasks, [ :list_id, :status, :due_at ], name: 'index_tasks_on_list_status_due_at' unless index_exists?(:tasks, [ :list_id, :status, :due_at ], name: 'index_tasks_on_list_status_due_at')
    add_index :tasks, [ :creator_id, :status ], name: 'index_tasks_on_creator_status' unless index_exists?(:tasks, [ :creator_id, :status ], name: 'index_tasks_on_creator_status')

    # Add indexes for list queries
    add_index :lists, [ :user_id, :created_at ], name: 'index_lists_on_user_created_at' unless index_exists?(:lists, [ :user_id, :created_at ], name: 'index_lists_on_user_created_at')
    add_index :lists, [ :user_id, :deleted_at ], name: 'index_lists_on_user_deleted_at' unless index_exists?(:lists, [ :user_id, :deleted_at ], name: 'index_lists_on_user_deleted_at')

    # Add indexes for coaching relationships
    add_index :coaching_relationships, [ :coach_id, :status ], name: 'index_coaching_relationships_on_coach_status' unless index_exists?(:coaching_relationships, [ :coach_id, :status ], name: 'index_coaching_relationships_on_coach_status')
    add_index :coaching_relationships, [ :client_id, :status ], name: 'index_coaching_relationships_on_client_status' unless index_exists?(:coaching_relationships, [ :client_id, :status ], name: 'index_coaching_relationships_on_client_status')

    # Add indexes for memberships
    add_index :memberships, [ :user_id, :list_id ], name: 'index_memberships_on_user_list' unless index_exists?(:memberships, [ :user_id, :list_id ], name: 'index_memberships_on_user_list')
    add_index :memberships, [ :list_id, :user_id ], name: 'index_memberships_on_list_user' unless index_exists?(:memberships, [ :list_id, :user_id ], name: 'index_memberships_on_list_user')

    # Add indexes for notification logs
    add_index :notification_logs, [ :user_id, :created_at ], name: 'index_notification_logs_on_user_created_at' unless index_exists?(:notification_logs, [ :user_id, :created_at ], name: 'index_notification_logs_on_user_created_at')
    add_index :notification_logs, [ :task_id, :created_at ], name: 'index_notification_logs_on_task_created_at' unless index_exists?(:notification_logs, [ :task_id, :created_at ], name: 'index_notification_logs_on_task_created_at')

    # Add indexes for user locations
    add_index :user_locations, [ :user_id, :recorded_at ], name: 'index_user_locations_on_user_recorded_at' unless index_exists?(:user_locations, [ :user_id, :recorded_at ], name: 'index_user_locations_on_user_recorded_at')

    # Add indexes for escalation queries
    add_index :item_escalations, [ :task_id, :escalation_level ], name: 'index_item_escalations_on_task_level' unless index_exists?(:item_escalations, [ :task_id, :escalation_level ], name: 'index_item_escalations_on_task_level')
    add_index :item_escalations, [ :escalation_level, :blocking_app ], name: 'index_item_escalations_on_level_blocking' unless index_exists?(:item_escalations, [ :escalation_level, :blocking_app ], name: 'index_item_escalations_on_level_blocking')
  end
end
