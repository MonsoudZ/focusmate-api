# frozen_string_literal: true

class StaleDeviceCleanupJob < ApplicationJob
  queue_as :maintenance

  # Devices not seen in this many days are considered stale
  STALE_THRESHOLD_DAYS = Integer(ENV.fetch("STALE_DEVICE_DAYS", 90))

  # Run weekly to soft-delete devices that haven't been seen in a while
  # These are likely uninstalled apps or old devices
  #
  # Scheduled via Solid Queue recurring tasks (config/recurring.yml)
  #
  def perform
    cutoff_date = STALE_THRESHOLD_DAYS.days.ago

    stale_devices = Device
                      .where("last_seen_at < ? OR last_seen_at IS NULL", cutoff_date)
                      .where(deleted_at: nil)

    # Soft delete in batches with bulk updates to avoid per-row instantiation.
    stale_count = bulk_soft_delete(stale_devices)

    Rails.logger.info(
      event: "stale_device_cleanup_completed",
      threshold_days: STALE_THRESHOLD_DAYS,
      cutoff_date: cutoff_date.iso8601,
      devices_cleaned: stale_count,
      active_devices: Device.where(deleted_at: nil).count
    )

    stale_count
  end

  private

  def bulk_soft_delete(scope)
    deleted = 0
    timestamp = Time.current

    scope.in_batches(of: 1000) do |batch|
      deleted += batch.update_all(deleted_at: timestamp, updated_at: timestamp)
    end

    deleted
  end
end
