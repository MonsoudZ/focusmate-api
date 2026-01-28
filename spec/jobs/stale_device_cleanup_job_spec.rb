# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaleDeviceCleanupJob, type: :job do
  let(:user) { create(:user) }

  describe "#perform" do
    it "soft-deletes devices not seen within threshold" do
      stale_device = create(:device, user: user, last_seen_at: 91.days.ago)
      active_device = create(:device, user: user, last_seen_at: 1.day.ago)

      described_class.new.perform

      expect(stale_device.reload.deleted_at).to be_present
      expect(active_device.reload.deleted_at).to be_nil
    end

    it "soft-deletes devices with nil last_seen_at older than threshold" do
      device = create(:device, user: user)
      device.update_column(:last_seen_at, nil)

      # The cutoff is 90 days ago, and nil last_seen_at is treated as stale
      described_class.new.perform

      expect(device.reload.deleted_at).to be_present
    end

    it "returns count of stale devices" do
      create(:device, user: user, last_seen_at: 100.days.ago)
      create(:device, user: user, last_seen_at: 95.days.ago)
      create(:device, user: user, last_seen_at: 1.day.ago)

      result = described_class.new.perform

      expect(result).to eq(2)
    end

    it "returns 0 when no stale devices exist" do
      create(:device, user: user, last_seen_at: 1.day.ago)

      result = described_class.new.perform

      expect(result).to eq(0)
    end

    it "does not re-delete already soft-deleted devices" do
      device = create(:device, user: user, last_seen_at: 100.days.ago)
      device.soft_delete!
      original_deleted_at = device.deleted_at

      result = described_class.new.perform

      expect(result).to eq(0)
      expect(device.reload.deleted_at).to eq(original_deleted_at)
    end

    it "respects custom threshold from env" do
      stub_const("StaleDeviceCleanupJob::STALE_THRESHOLD_DAYS", 30)

      device_35_days = create(:device, user: user, last_seen_at: 35.days.ago)
      device_25_days = create(:device, user: user, last_seen_at: 25.days.ago)

      described_class.new.perform

      expect(device_35_days.reload.deleted_at).to be_present
      expect(device_25_days.reload.deleted_at).to be_nil
    end

    it "logs cleanup results" do
      create(:device, user: user, last_seen_at: 100.days.ago)

      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "stale_device_cleanup_completed",
        threshold_days: described_class::STALE_THRESHOLD_DAYS,
        devices_cleaned: 1
      ))

      described_class.new.perform
    end

    it "is enqueued to the maintenance queue" do
      expect(described_class.new.queue_name).to eq("maintenance")
    end
  end
end
