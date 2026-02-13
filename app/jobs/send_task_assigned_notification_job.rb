# frozen_string_literal: true

class SendTaskAssignedNotificationJob < ApplicationJob
  queue_as :default

  def perform(task_id:, assigned_by_id:)
    task = Task.find_by(id: task_id)
    return unless task&.assigned_to

    assigned_by = User.find_by(id: assigned_by_id)
    return unless assigned_by

    PushNotifications::Sender.send_task_assigned(
      to_user: task.assigned_to,
      task: task,
      assigned_by: assigned_by
    )
  end
end
