# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsCleanupJob, type: :job do
  let(:user) { create(:user) }

  describe "#perform" do
    it "removes analytics events older than retention period" do
      # Create old events
      old_event = AnalyticsEvent.create!(
        user: user,
        event_type: "app_opened",
        occurred_at: 100.days.ago
      )

      # Create recent event
      recent_event = AnalyticsEvent.create!(
        user: user,
        event_type: "app_opened",
        occurred_at: 1.day.ago
      )

      described_class.new.perform

      expect(AnalyticsEvent.exists?(old_event.id)).to be false
      expect(AnalyticsEvent.exists?(recent_event.id)).to be true
    end

    it "respects the retention period setting" do
      stub_const("AnalyticsCleanupJob::RETENTION_DAYS", 30)

      event_35_days_old = AnalyticsEvent.create!(
        user: user,
        event_type: "app_opened",
        occurred_at: 35.days.ago
      )

      event_25_days_old = AnalyticsEvent.create!(
        user: user,
        event_type: "app_opened",
        occurred_at: 25.days.ago
      )

      described_class.new.perform

      expect(AnalyticsEvent.exists?(event_35_days_old.id)).to be false
      expect(AnalyticsEvent.exists?(event_25_days_old.id)).to be true
    end

    it "returns count of deleted events" do
      3.times do
        AnalyticsEvent.create!(
          user: user,
          event_type: "app_opened",
          occurred_at: 100.days.ago
        )
      end

      result = described_class.new.perform

      expect(result).to eq(3)
    end

    it "is enqueued to maintenance queue" do
      expect(described_class.new.queue_name).to eq("maintenance")
    end
  end
end
