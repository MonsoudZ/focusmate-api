class AddNotificationLogsIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Essential index for user queries with created_at ordering
    add_index :notification_logs, [ :user_id, :created_at ],
              name: 'idx_notification_logs_user_created_at',
              algorithm: :concurrently

    # Index for read status filtering (metadata JSONB)
    add_index :notification_logs, "((metadata->>'read'))",
              name: 'idx_notification_logs_read_status',
              algorithm: :concurrently
  end
end
