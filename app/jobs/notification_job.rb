# frozen_string_literal: true

class NotificationJob < ApplicationJob
  queue_as :push

  def perform(method, *args)
    # Support different notification types
    case method
    when /^coaching_/
      handle_coaching_notification(method, *args)
    when /^task_/, /^new_item_/, /^explanation_/, /^send_reminder/, /^app_blocking_/, /^alert_coaches_/, /^location_based_/, /^recurring_task_/
      handle_task_notification(method, *args)
    when /^list_/
      handle_list_notification(method, *args)
    when /^send_daily_summary/
      handle_summary_notification(method, *args)
    when /^send_test_notification/
      handle_test_notification(method, *args)
    else
      Rails.logger.warn "Unknown notification method: #{method}"
    end
  rescue => e
    Rails.logger.error "NotificationJob failed for #{method}: #{e.message}"
    raise e # Re-raise to trigger retry
  end

  private

  def handle_coaching_notification(method, rel_id)
    rel = CoachingRelationship.find(rel_id)
    NotificationService.public_send(method, rel)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "NotificationJob failed: CoachingRelationship #{rel_id} not found: #{e.message}"
    # Don't re-raise - this is expected if relationship was deleted
  end

  def handle_task_notification(method, task_id)
    task = Task.find(task_id)
    NotificationService.public_send(method, task)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "NotificationJob failed: Task #{task_id} not found: #{e.message}"
  end

  def handle_list_notification(method, list_id, *extra_args)
    list = List.find(list_id)
    # For list_shared, convert coach_id to User object
    if method == "list_shared" && extra_args.first.is_a?(Integer)
      coach_id = extra_args.first
      coach = User.find(coach_id)
      NotificationService.public_send(method, list, coach)
    else
      NotificationService.public_send(method, list, *extra_args)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "NotificationJob failed: List #{list_id} not found: #{e.message}"
  end

  def handle_summary_notification(method, summary_id)
    summary = DailySummary.find(summary_id)
    NotificationService.public_send(method, summary)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "NotificationJob failed: DailySummary #{summary_id} not found: #{e.message}"
  end

  def handle_test_notification(method, user_id, message = "Test notification")
    user = User.find(user_id)
    NotificationService.public_send(method, user, message)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "NotificationJob failed: User #{user_id} not found: #{e.message}"
  end
end
