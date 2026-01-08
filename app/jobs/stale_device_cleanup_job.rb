# frozen_string_literal: true

class StaleDeviceCleanupJob < ApplicationJob
  queue_as :maintenance

  # Devices not seen in this many days are considered stale
  STALE_THRESHOLD_DAYS = ENV.fetch("STALE_DEVICE_DAYS", 90).to_i

  # Run weekly to soft-delete devices that haven't been seen in a while
  # These are likely uninstalled apps or old devices
  #
  # Schedule with sidekiq-cron or call from a cron job:
  #   StaleDeviceCleanupJob.perform_later
  #
  def perform
    cutoff_date = STALE_THRESHOLD_DAYS.days.ago

    stale_devices = Device
                      .where("last_seen_at < ? OR last_seen_at IS NULL", cutoff_date)
                      .where(deleted_at: nil)

    stale_count = stale_devices.count

    # Soft delete in batches to avoid long transactions
    stale_devices.find_each do |device|
      device.soft_delete!
    end

    Rails.logger.info(
      event: "stale_device_cleanup_completed",
      threshold_days: STALE_THRESHOLD_DAYS,
      cutoff_date: cutoff_date.iso8601,
      devices_cleaned: stale_count,
      active_devices: Device.where(deleted_at: nil).count
    )

    stale_count
  end
end