# frozen_string_literal: true

class AnalyticsTracker
  SENTRY_ERROR_TTL = 5.minutes

  class << self
    # Task events
    def task_created(task, user)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_created",
        metadata: {
          priority: task.priority,
          starred: task.starred,
          has_due_date: task.due_at.present?,
          due_in_hours: task.due_at ? ((task.due_at - Time.current) / 1.hour).round : nil
        }
      )
    end

    def task_completed(task, user, was_overdue:, minutes_overdue: 0, missed_reason: nil)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_completed",
        metadata: {
          priority: task.priority,
          starred: task.starred,
          was_overdue: was_overdue,
          minutes_overdue: minutes_overdue,
          missed_reason: missed_reason,
          time_to_complete_hours: ((Time.current - task.created_at) / 1.hour).round(1),
          completed_day_of_week: Time.current.strftime("%A"),
          completed_hour: Time.current.hour
        }
      )
    end

    def task_reopened(task, user)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_reopened",
        metadata: {}
      )
    end

    def task_deleted(task, user)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_deleted",
        metadata: {
          was_completed: task.completed_at.present?,
          was_overdue: task.due_at.present? && task.due_at < Time.current && task.completed_at.nil?,
          age_hours: ((Time.current - task.created_at) / 1.hour).round(1)
        }
      )
    end

    def task_starred(task, user)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_starred",
        metadata: {
          priority: task.priority,
          age_hours: ((Time.current - task.created_at) / 1.hour).round(1)
        }
      )
    end

    def task_unstarred(task, user)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_unstarred",
        metadata: {}
      )
    end

    def task_priority_changed(task, user, from:, to:)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_priority_changed",
        metadata: {
          from: from,
          to: to,
          age_hours: ((Time.current - task.created_at) / 1.hour).round(1)
        }
      )
    end

    def task_edited(task, user, changes:)
      record(
        user: user,
        task: task,
        list: task.list,
        event_type: "task_edited",
        metadata: {
          fields_changed: changes.is_a?(Array) ? changes : changes.keys
        }
      )
    end

    # List events
    def list_created(list, user)
      record(
        user: user,
        list: list,
        event_type: "list_created",
        metadata: {
          visibility: list.visibility
        }
      )
    end

    def list_deleted(list, user)
      record(
        user: user,
        list: list,
        event_type: "list_deleted",
        metadata: {
          task_count: list.tasks_count,
          age_days: ((Time.current - list.created_at) / 1.day).round
        }
      )
    end

    def list_shared(list, user, shared_with:, role:)
      record(
        user: user,
        list: list,
        event_type: "list_shared",
        metadata: {
          shared_with_user_id: shared_with.id,
          role: role
        }
      )
    end

    # User events
    def app_opened(user, platform:, version: nil)
      record(
        user: user,
        event_type: "app_opened",
        metadata: {
          platform: platform,
          version: version,
          day_of_week: Time.current.strftime("%A"),
          hour: Time.current.hour
        }
      )
    end

    def session_started(user, platform:, version: nil)
      record(
        user: user,
        event_type: "session_started",
        metadata: {
          platform: platform,
          version: version
        }
      )
    end

    private

    def record(user:, event_type:, metadata: {}, task: nil, list: nil)
      AnalyticsEventJob.perform_later(
        user_id: user.id,
        task_id: task&.id,
        list_id: list&.id,
        event_type: event_type,
        metadata: metadata,
        occurred_at: Time.current.iso8601
      )
    rescue StandardError => e
      Rails.logger.error("AnalyticsTracker failed to enqueue: #{e.message}")
      report_enqueue_failure_once(e, user_id: user.id, event_type: event_type)
      # Don't raise - analytics should never break the app
    end

    def report_enqueue_failure_once(error, **context)
      return unless defined?(Sentry)
      return if recently_reported?(error)

      mark_reported(error)
      Sentry.capture_exception(error, extra: context)
    rescue StandardError => sentry_error
      Rails.logger.error("AnalyticsTracker Sentry report failed: #{sentry_error.message}")
    end

    def recently_reported?(error)
      Rails.cache.read(sentry_cache_key(error)).present?
    end

    def mark_reported(error)
      Rails.cache.write(sentry_cache_key(error), true, expires_in: SENTRY_ERROR_TTL)
    end

    def sentry_cache_key(error)
      digest = Digest::SHA256.hexdigest(error.message.to_s)[0, 16]
      "analytics_tracker:enqueue_error:#{error.class.name}:#{digest}"
    end
  end
end
