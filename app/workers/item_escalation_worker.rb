class ItemEscalationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :critical, retry: 3

  def perform
    Rails.logger.info "[ItemEscalationWorker] Starting escalation check at #{Time.current}"
    
    # Find all overdue tasks that can't be snoozed
    overdue_tasks = Task.overdue
                        .where(can_be_snoozed: false)
                        .includes(:escalation, :list, :creator)
    
    Rails.logger.info "[ItemEscalationWorker] Found #{overdue_tasks.count} overdue un-snoozable tasks"
    
    overdue_tasks.find_each do |task|
      process_task_escalation(task)
    end
    
    Rails.logger.info "[ItemEscalationWorker] Completed escalation check"
  end

  private

  def process_task_escalation(task)
    escalation = task.escalation || task.create_escalation!
    
    # Calculate time since last notification
    time_since_last = if escalation.last_notification_at
                        (Time.current - escalation.last_notification_at) / 60.0
                      else
                        999 # Force notification if never sent
                      end
    
    # Check if it's time to send another notification
    if time_since_last >= task.notification_interval_minutes
      Rails.logger.info "[ItemEscalationWorker] Escalating task ##{task.id}: '#{task.title}'"
      
      # Increment notification count and update escalation level
      escalation.increment!(:notification_count)
      escalation.update!(last_notification_at: Time.current)
      
      # Mark as overdue if not already
      if escalation.became_overdue_at.nil?
        escalation.update!(became_overdue_at: Time.current)
      end
      
      # Check and update escalation level
      check_escalation_level(task, escalation)
      
      # Send notification
      NotificationService.send_reminder(task, escalation.escalation_level)
      
      # Check if we should notify coaches (at critical level)
      if escalation.escalation_level == 'critical' && !escalation.coaches_notified?
        escalation.update!(coaches_notified: true, coaches_notified_at: Time.current)
        NotificationService.alert_coaches_of_overdue(task)
      end
      
      # Check if app should be blocked
      if task.should_block_app? && !escalation.blocking_app?
        Rails.logger.warn "[ItemEscalationWorker] Blocking app for task ##{task.id}"
        start_blocking_app(task, escalation)
      end
    end
    
  rescue => e
    Rails.logger.error "[ItemEscalationWorker] Error processing task ##{task.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def check_escalation_level(task, escalation)
    minutes_overdue = task.minutes_overdue
    
    new_level = case task.priority
                when 3 # Urgent
                  if minutes_overdue > 120
                    'blocking'
                  elsif minutes_overdue > 60
                    'critical'
                  elsif minutes_overdue > 30
                    'warning'
                  else
                    'normal'
                  end
                when 2 # High
                  if minutes_overdue > 240
                    'blocking'
                  elsif minutes_overdue > 120
                    'critical'
                  elsif minutes_overdue > 60
                    'warning'
                  else
                    'normal'
                  end
                else # Medium/Low
                  if minutes_overdue > 240
                    'critical'
                  elsif minutes_overdue > 120
                    'warning'
                  else
                    'normal'
                  end
                end
    
    if new_level != escalation.escalation_level
      Rails.logger.info "[ItemEscalationWorker] Task ##{task.id} escalated from #{escalation.escalation_level} to #{new_level}"
      escalation.update!(escalation_level: new_level)
    end
  end

  def start_blocking_app(task, escalation)
    escalation.update!(
      blocking_app: true,
      blocking_started_at: Time.current
    )
    
    # Send critical blocking notification
    NotificationService.app_blocking_started(task)
    
    # Notify coaches immediately
    unless escalation.coaches_notified?
      escalation.update!(coaches_notified: true, coaches_notified_at: Time.current)
      NotificationService.alert_coaches_of_overdue(task)
    end
  end
end
