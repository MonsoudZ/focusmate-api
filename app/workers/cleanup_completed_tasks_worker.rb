class CleanupCompletedTasksWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :low, retry: 1

  def perform
    # Optional: Archive or delete very old completed tasks
    # Be careful with this - users might want history!
    
    cutoff_date = 1.year.ago
    
    # Find completed non-recurring tasks older than 1 year
    old_tasks = Task.where.not(completed_at: nil)
                    .where('completed_at < ?', cutoff_date)
                    .where(recurring_template_id: nil) # Don't delete recurring instances
    
    count = old_tasks.count
    
    Rails.logger.info "[CleanupCompletedTasksWorker] Found #{count} tasks to archive"
    
    # Instead of deleting, you might want to:
    # 1. Move to archive table
    # 2. Export to S3
    # 3. Just leave them (storage is cheap)
    
    # For now, let's just log
    Rails.logger.info "[CleanupCompletedTasksWorker] Archiving disabled - keeping all completed tasks"
  end
end
