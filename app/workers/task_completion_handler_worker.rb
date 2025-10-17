class TaskCompletionHandlerWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 2

  def perform(task_id)
    task = Task.find(task_id)
    
    Rails.logger.info "[TaskCompletionHandlerWorker] Processing completion for task ##{task_id}"
    
    # Clear escalation
    if task.escalation
      task.escalation.clear!
      Rails.logger.info "[TaskCompletionHandlerWorker] Cleared escalation for task ##{task_id}"
    end
    
    # Notify coaches
    if task.created_by_coach?
      NotificationService.task_completed(task)
      Rails.logger.info "[TaskCompletionHandlerWorker] Notified coaches of completion"
    end
    
    # Generate next recurring instance if applicable
    if task.recurring_template.present?
      next_instance = task.recurring_template.generate_next_instance
      if next_instance
        Rails.logger.info "[TaskCompletionHandlerWorker] Generated next recurring instance ##{next_instance.id}"
      end
    end
    
    # Check if parent task should be completed (all subtasks done)
    if task.parent_item_id.present?
      parent = task.parent_item
      if parent.all_subtasks_completed? && parent.completed_at.nil?
        parent.complete!
        Rails.logger.info "[TaskCompletionHandlerWorker] Auto-completed parent task ##{parent.id}"
      end
    end
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "[TaskCompletionHandlerWorker] Task ##{task_id} not found"
  rescue => e
    Rails.logger.error "[TaskCompletionHandlerWorker] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Retry
  end
end
