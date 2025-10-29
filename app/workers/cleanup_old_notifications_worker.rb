class CleanupOldNotificationsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, retry: 1

  def perform
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info "[CleanupOldNotificationsWorker] Starting cleanup"

    # Simple Redis lock to avoid overlapping runs
    lock_key = "cleanup_old_notifications:lock"
    acquired = false
    begin
      acquired = Sidekiq.redis { |r| r.set(lock_key, 1, nx: true, ex: 600) }
      if !acquired
        Rails.logger.warn "[CleanupOldNotificationsWorker] Skipping - lock already held"
        return
      end

      # Retention windows (days), configurable via ENV
      notif_retention_days = Integer(ENV.fetch("NOTIFICATION_LOG_RETENTION_DAYS", 90)) rescue 90
      location_retention_days = Integer(ENV.fetch("USER_LOCATION_RETENTION_DAYS", 30)) rescue 30
      escalation_retention_days = Integer(ENV.fetch("ESCALATION_CLEANUP_DAYS", 30)) rescue 30

      notif_cutoff = notif_retention_days.days.ago
      location_cutoff = location_retention_days.days.ago
      escalation_cutoff = escalation_retention_days.days.ago

      deleted_notifications = 0
      deleted_locations = 0
      deleted_escalations = 0

      # Batch delete NotificationLog
      NotificationLog.where("created_at < ?", notif_cutoff)
                     .in_batches(of: 1_000) do |relation|
        count = relation.delete_all
        deleted_notifications += count
      end
      Rails.logger.info "[CleanupOldNotificationsWorker] Deleted #{deleted_notifications} old notification logs (> #{notif_retention_days} days)"

      # Batch delete UserLocation (use recorded_at cutoff)
      UserLocation.with_deleted.where("recorded_at < ?", location_cutoff)
                  .in_batches(of: 1_000) do |relation|
        # If you prefer soft-delete, replace delete_all with update_all(deleted_at: Time.current)
        count = relation.delete_all
        deleted_locations += count
      end
      Rails.logger.info "[CleanupOldNotificationsWorker] Deleted #{deleted_locations} old location records (> #{location_retention_days} days)"

      # Batch delete ItemEscalation for tasks completed before cutoff (avoid joins)
      old_completed_task_ids = Task.where.not(completed_at: nil)
                                   .where("completed_at < ?", escalation_cutoff)
      ItemEscalation.where(task_id: old_completed_task_ids)
                    .in_batches(of: 1_000) do |relation|
        deleted_escalations += relation.delete_all
      end
      Rails.logger.info "[CleanupOldNotificationsWorker] Deleted #{deleted_escalations} old task escalations (tasks completed > #{escalation_retention_days} days ago)"

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      Rails.logger.info "[CleanupOldNotificationsWorker] Cleanup completed in #{duration_ms}ms"
    ensure
      # Let lock expire naturally, but try to release early
      Sidekiq.redis { |r| r.del(lock_key) } if acquired
    end
  end
end
