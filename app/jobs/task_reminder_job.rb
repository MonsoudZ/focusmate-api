# frozen_string_literal: true

class TaskReminderJob < ApplicationJob
  include RateLimitedSentryReporting

  queue_as :default
  ELIGIBLE_STATUSES = %w[pending in_progress].freeze
  DEFAULT_NOTIFICATION_INTERVAL_MINUTES = 10
  SENTRY_ERROR_TTL = 5.minutes

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
    recipient = task.assigned_to || task.creator

    # Lock per task to avoid duplicate sends when concurrent workers pick up the same row.
    task.with_lock do
      return unless recipient
      return unless reminder_due_now?(task)

      delivered = PushNotifications::Sender.send_task_reminder(
        to_user: recipient,
        task: task
      )

      if delivered
        timestamp = Time.current
        task.update_columns(reminder_sent_at: timestamp, updated_at: timestamp)
        Rails.logger.info(
          event: "task_reminder_sent",
          task_id: task.id,
          recipient_id: recipient.id
        )
      else
        Rails.logger.warn(
          event: "task_reminder_not_delivered",
          task_id: task.id,
          recipient_id: recipient.id
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error(
      event: "task_reminder_failed",
      task_id: task.id,
      list_id: task.list_id,
      recipient_id: recipient&.id,
      error_class: e.class.name,
      error_message: e.message
    )
    report_reminder_error(e, task: task, recipient: recipient)
  end

  def reminder_due_now?(task)
    reference_time = Time.current

    return false unless task.due_at.present?
    return false unless task.due_at > reference_time
    return false unless ELIGIBLE_STATUSES.include?(task.status)
    return false if task.deleted_at.present?
    return false if task.is_template?

    interval_minutes = task.notification_interval_minutes || DEFAULT_NOTIFICATION_INTERVAL_MINUTES
    interval_seconds = interval_minutes * 60
    return false unless task.due_at <= reference_time + interval_seconds

    threshold = task.due_at - interval_seconds
    task.reminder_sent_at.nil? || task.reminder_sent_at < threshold
  end

  def report_reminder_error(error, task:, recipient:)
    cache_key = "task_reminder_job:error:#{error.class.name}:#{error.message}"

    report_error_once(
      error,
      cache_key: cache_key,
      ttl: SENTRY_ERROR_TTL,
      extra: {
        task_id: task.id,
        list_id: task.list_id,
        recipient_id: recipient&.id
      }
    )
  end
end
