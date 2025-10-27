class RemoveNotificationLogTypeConstraint < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :notification_logs, name: "chk_notification_log_type"
  end
end
