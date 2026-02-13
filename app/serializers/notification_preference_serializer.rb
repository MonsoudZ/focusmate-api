# frozen_string_literal: true

class NotificationPreferenceSerializer
  def self.one(preference)
    {
      nudge_enabled: preference.nudge_enabled,
      task_assigned_enabled: preference.task_assigned_enabled,
      list_joined_enabled: preference.list_joined_enabled,
      task_reminder_enabled: preference.task_reminder_enabled,
      updated_at: preference.updated_at
    }
  end
end
