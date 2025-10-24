class AddMissingConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add unique constraint on user email
    add_index :users, :email, unique: true, name: 'index_users_on_email_unique'

    # Add check constraints for enum values
    add_check_constraint :users, "role IN ('client', 'coach')", name: 'check_users_role'
    add_check_constraint :coaching_relationships, "status IN ('pending', 'active', 'inactive', 'declined')", name: 'check_coaching_relationships_status'
    add_check_constraint :tasks, "status IN (0, 1, 2)", name: 'check_tasks_status'
    add_check_constraint :tasks, "visibility IN (0, 1, 2)", name: 'check_tasks_visibility'
    add_check_constraint :item_escalations, "escalation_level IN ('normal', 'warning', 'critical', 'blocking')", name: 'check_item_escalations_escalation_level'

    # Add not null constraints where needed
    change_column_null :users, :email, false
    change_column_null :users, :encrypted_password, false
    change_column_null :lists, :name, false
    change_column_null :tasks, :title, false
    change_column_null :tasks, :due_at, false

    # Add indexes for performance
    add_index :tasks, [ :list_id, :status, :due_at ], name: 'index_tasks_on_list_status_due_at'
    add_index :tasks, [ :creator_id, :status ], name: 'index_tasks_on_creator_status'
    add_index :notification_logs, [ :user_id, :created_at ], name: 'index_notification_logs_on_user_created_at'
    add_index :user_locations, [ :user_id, :recorded_at ], name: 'index_user_locations_on_user_recorded_at'
  end
end
