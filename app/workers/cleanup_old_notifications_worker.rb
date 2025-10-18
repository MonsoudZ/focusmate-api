class CleanupOldNotificationsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, retry: 1

  def perform
    Rails.logger.info "[CleanupOldNotificationsWorker] Starting cleanup"

    # Delete notification logs older than 90 days
    cutoff_date = 90.days.ago
    deleted_count = NotificationLog.where("created_at < ?", cutoff_date).delete_all

    Rails.logger.info "[CleanupOldNotificationsWorker] Deleted #{deleted_count} old notification logs"

    # Delete old user location records (keep last 30 days)
    location_cutoff = 30.days.ago
    deleted_locations = UserLocation.where("recorded_at < ?", location_cutoff).delete_all

    Rails.logger.info "[CleanupOldNotificationsWorker] Deleted #{deleted_locations} old location records"

    # Clean up old escalations for completed tasks
    ItemEscalation.joins(:task)
                  .where.not(tasks: { completed_at: nil })
                  .where("tasks.completed_at < ?", 30.days.ago)
                  .delete_all

    Rails.logger.info "[CleanupOldNotificationsWorker] Cleanup completed"
  end
end
