class EnhanceNotificationLogs < ActiveRecord::Migration[8.0]
  def change
    # Add missing columns
    add_column :notification_logs, :delivery_method, :string
    add_column :notification_logs, :deleted_at, :datetime
    
    # Make notification_type and message NOT NULL
    change_column_null :notification_logs, :notification_type, false
    change_column_null :notification_logs, :message, false
    
    # Set default for metadata
    change_column_default :notification_logs, :metadata, {}
    
    # Add new indexes for performance (only if they don't exist)
    add_index :notification_logs, :deleted_at unless index_exists?(:notification_logs, :deleted_at)
    add_index :notification_logs, [:user_id, :created_at] unless index_exists?(:notification_logs, [:user_id, :created_at])
    add_index :notification_logs, [:task_id, :created_at] unless index_exists?(:notification_logs, [:task_id, :created_at])
    add_index :notification_logs, :delivery_method unless index_exists?(:notification_logs, :delivery_method)
    
    # Partial indexes for commonly queried data (only if they don't exist)
    add_index :notification_logs, :delivered, where: "deleted_at IS NULL" unless index_exists?(:notification_logs, :delivered, where: "deleted_at IS NULL")
    add_index :notification_logs, :delivery_method, where: "deleted_at IS NULL" unless index_exists?(:notification_logs, :delivery_method, where: "deleted_at IS NULL")
    
    # Add database-level constraints
    execute <<~SQL
      ALTER TABLE notification_logs
      ADD CONSTRAINT chk_notification_log_delivery_method
      CHECK (delivery_method IS NULL OR delivery_method IN ('email','push','sms','in_app'));
    SQL

    execute <<~SQL
      ALTER TABLE notification_logs
      ADD CONSTRAINT chk_notification_log_type
      CHECK (notification_type IN (
        'task_reminder','task_due_soon','task_overdue','task_escalated',
        'system_announcement','coaching_message','urgent_alert'
      ));
    SQL
  end
end
