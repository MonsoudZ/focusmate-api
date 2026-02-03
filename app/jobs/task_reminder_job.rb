# frozen_string_literal: true

class TaskReminderJob < ApplicationJob
  queue_as :default

  # Run every minute via sidekiq-cron
  # Finds tasks due soon and sends reminder notifications
  def perform
    tasks_needing_reminder.find_each do |task|
      send_reminder(task)
    end
  end

  private

  def tasks_needing_reminder
    # Find incomplete tasks that:
    # 1. Have a due date within their notification interval (default 10 min)
    # 2. Haven't had a reminder sent yet (or sent before previous interval)
    # 3. Are not templates
    # 4. Are not deleted
    Task
      .includes(:assigned_to, :creator)  # Prevent N+1 queries
      .where(status: [ :pending, :in_progress ])
      .where(deleted_at: nil)
      .where(is_template: [ false, nil ])
      .where("due_at IS NOT NULL")
      .where("due_at > ?", Time.current)
      .where("due_at <= ?", max_reminder_window.from_now)
      .where(reminder_not_recently_sent)
  end

  def reminder_not_recently_sent
    # Either never sent, or sent more than interval ago
    "reminder_sent_at IS NULL OR reminder_sent_at < due_at - (COALESCE(notification_interval_minutes, 10) * INTERVAL '1 minute')"
  end

  def max_reminder_window
    # Look ahead for tasks due in the next 30 minutes
    # (covers even the longest reasonable notification_interval_minutes)
    Task::MAX_NOTIFICATION_INTERVAL_MINUTES.minutes
  end

  def send_reminder(task)
    # Determine who to notify: assignee if assigned, otherwise creator
    recipient = task.assigned_to || task.creator

    return unless recipient

    # Check if it's time to send based on task's notification interval
    interval = task.notification_interval_minutes || 10
    return unless task.due_at <= interval.minutes.from_now

    delivered = PushNotifications::Sender.send_task_reminder(
      to_user: recipient,
      task: task
    )

    if delivered
      task.update_column(:reminder_sent_at, Time.current)
      Rails.logger.info("Sent reminder for task #{task.id} to user #{recipient.id}")
    else
      Rails.logger.warn("Reminder for task #{task.id} was not delivered to any device")
    end
  rescue => e
    Rails.logger.error("Failed to send reminder for task #{task.id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
