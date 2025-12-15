# frozen_string_literal: true

class NudgeJob
  include Sidekiq::Job

  # Job configuration
  sidekiq_options queue: :notifications, retry: 3, backtrace: true

  # Retry configuration
  sidekiq_retry_in do |count, exception|
    case exception
    when ActiveRecord::RecordNotFound
      0 # Don't retry if task doesn't exist
    when StandardError
      # Check if it's an APNs rate limit error
      if exception.message.include?("rate limit")
        # Exponential backoff for rate limits: 60s, 120s, 240s, max 5 retries
        [60 * (count + 1), 300].min
      else
        30 * (count + 1) # Default exponential backoff
      end
    else
      30 * (count + 1) # Default exponential backoff
    end
  end

  # Limit retries for APNs rate limits to prevent spam
  sidekiq_retries_exhausted do |msg, exception|
    if exception.message.include?("rate limit")
      Rails.logger.error "[NudgeJob] Retries exhausted for rate-limited APNs request: #{msg['args'].inspect}"
    end
  end

  def perform(task_id, reason = nil, options = {})
    start_time = Time.current
    job_id = jid || SecureRandom.uuid

    Rails.logger.info "[NudgeJob] Starting job #{job_id} for task #{task_id}, reason: #{reason || 'none'}"

    begin
      # Validate inputs
      validate_inputs(task_id, reason, options)

      # Find and validate task
      task = find_task(task_id)
      return if task.nil? # Early return if task not found

      # Get list and members
      list = task.list
      members = get_list_members(list)

      if members.empty?
        Rails.logger.warn "[NudgeJob] No members found for list #{list.id}, skipping notifications"
        return
      end

      # Send notifications
      notification_stats = send_notifications(task, members, reason, options)

      # Log completion
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info "[NudgeJob] Completed job #{job_id} in #{duration}ms. " \
                        "Sent: #{notification_stats[:sent]}, " \
                        "Failed: #{notification_stats[:failed]}, " \
                        "Skipped: #{notification_stats[:skipped]}"

    rescue => e
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.error "[NudgeJob] Job #{job_id} failed after #{duration}ms: #{e.class}: #{e.message}"
      Rails.logger.error "[NudgeJob] Backtrace: #{e.backtrace.first(5).join(', ')}"

      # Re-raise to trigger Sidekiq retry mechanism
      raise e
    end
  end

  private

  def validate_inputs(task_id, reason, options)
    unless task_id.present? && task_id.is_a?(Numeric)
      raise ArgumentError, "Invalid task_id: #{task_id}"
    end

    if reason.present? && reason.length > 500
      raise ArgumentError, "Reason too long: #{reason.length} characters (max 500)"
    end

    if options.is_a?(Hash) && options[:priority].present?
      unless %w[low normal high].include?(options[:priority])
        raise ArgumentError, "Invalid priority: #{options[:priority]}"
      end
    end
  end

  def find_task(task_id)
    Task.find(task_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "[NudgeJob] Task #{task_id} not found: #{e.message}"
    nil
  end

  def get_list_members(list)
    return [] unless list.present?

    # Get active members only
    list.memberships
        .includes(:user)
        .joins(:user)
        .where(users: { active: true })
        .map(&:user)
  rescue => e
    Rails.logger.error "[NudgeJob] Failed to get list members: #{e.message}"
    []
  end

  def send_notifications(task, members, reason, options)
    stats = { sent: 0, failed: 0, skipped: 0 }

    # Prepare notification data
    notification_data = prepare_notification_data(task, reason, options)

    members.each do |user|
      begin
        # Check if user should receive notifications
        unless should_send_notification?(user, task, options)
          stats[:skipped] += 1
          next
        end

        # Get user's devices
        devices = get_user_devices(user)

        if devices.empty?
          Rails.logger.debug "[NudgeJob] No devices found for user #{user.id}"
          stats[:skipped] += 1
          next
        end

        # Send to each device
        devices.each do |device|
          send_to_device(device, notification_data, stats)
        end

      rescue => e
        Rails.logger.error "[NudgeJob] Failed to process user #{user.id}: #{e.message}"
        stats[:failed] += 1
      end
    end

    stats
  end

  def prepare_notification_data(task, reason, options)
    {
      title: notification_title(task, reason),
      body: push_body(task, reason),
      payload: {
        type: "task.nudge",
        task_id: task.id,
        list_id: task.list_id,
        priority: options[:priority] || "normal",
        timestamp: Time.current.iso8601
      }
    }
  end

  def notification_title(task, reason)
    if task.done?
      "Task Completed"
    elsif reason.present?
      "Task Reassigned"
    else
      "Task Reminder"
    end
  end

  def push_body(task, reason)
    # Truncate task title if too long
    title = truncate_text(task.title, 50)

    if task.done?
      "Completed: #{title}"
    elsif reason.present?
      reason_text = truncate_text(reason, 100)
      "Reassigned: #{title} — #{reason_text}"
    else
      "Due soon: #{title}"
    end
  end

  def should_send_notification?(user, task, options)
    # Check if user has notifications enabled
    return false unless user_notifications_enabled?(user)

    # Check if user is not the task creator (avoid self-notifications)
    return false if options[:skip_creator] && task.creator_id == user.id

    # Check if user has access to the task
    return false unless task.visible_to?(user)

    true
  end

  def user_notifications_enabled?(user)
    # Check user preferences
    return false if user.preferences&.dig("notifications", "enabled") == false

    # Check if user is active
    return false unless user.active?

    true
  end

  def get_user_devices(user)
    user.devices
        .where.not(apns_token: [ nil, "" ])
        .where(active: true)
        .find_each
  rescue => e
    Rails.logger.error "[NudgeJob] Failed to get devices for user #{user.id}: #{e.message}"
    []
  end

  def send_to_device(device, notification_data, stats)
    client = Apns.client
    unless client&.enabled?
      Rails.logger.debug "[NudgeJob] APNs not enabled, skipping device #{device.id}"
      stats[:skipped] += 1
      return
    end

    begin
      # Build APNs payload in the format expected by Apns::Client
      payload = {
        aps: {
          alert: {
            title: notification_data[:title],
            body: notification_data[:body]
          },
          sound: "default"
        },
        data: notification_data[:payload].merge(
          title: notification_data[:title],
          body: notification_data[:body],
          timestamp: Time.current.to_i
        )
      }

      response = client.send_notification(
        device.apns_token,
        payload,
        push_type: "alert",
        priority: 5,
        expiration: Time.now.to_i + 1.hour.to_i
      )

      if response[:ok]
        stats[:sent] += 1
        Rails.logger.debug "[NudgeJob] Sent notification to device #{device.id} for user #{device.user_id}"
      else
        # Handle APNs error responses
        case response[:status]
        when 410 # Unregistered
          Rails.logger.warn "[NudgeJob] Unregistered APNs token for device #{device.id}, removing device..."
          device.update!(active: false)
          stats[:failed] += 1
        when 429 # Rate limited
          Rails.logger.warn "[NudgeJob] Rate limited for device #{device.id}: #{response[:reason]}"
          # Re-raise to trigger retry
          raise StandardError, "APNs rate limit: #{response[:reason]}"
        else
          Rails.logger.error "[NudgeJob] APNs error for device #{device.id}: #{response[:status]} - #{response[:reason]}"
          stats[:failed] += 1
        end
      end

    rescue => e
      Rails.logger.error "[NudgeJob] Unexpected error for device #{device.id}: #{e.message}"
      # Only re-raise if it's a rate limit error (to trigger retry)
      raise e if e.message.include?("rate limit")
      stats[:failed] += 1
    end
  end

  def truncate_text(text, max_length)
    return text if text.length <= max_length

    text[0, max_length - 3] + "..."
  end

  # Class methods for job management
  class << self
    def enqueue_for_task(task_id, reason = nil, options = {})
      perform_async(task_id, reason, options)
    end

    def enqueue_for_task_with_delay(task_id, reason = nil, delay_seconds = 0, options = {})
      perform_in(delay_seconds, task_id, reason, options)
    end

    def enqueue_for_task_at(task_id, reason = nil, at_time = nil, options = {})
      perform_at(at_time, task_id, reason, options)
    end

    def job_stats
      {
        processed: Sidekiq::Stats.new.processed,
        failed: Sidekiq::Stats.new.failed,
        enqueued: Sidekiq::Queue.new("notifications").size,
        retry_set: Sidekiq::RetrySet.new.size
      }
    end
  end
end
