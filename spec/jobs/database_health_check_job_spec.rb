# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseHealthCheckJob, type: :job do
  describe "#perform" do
    before do
      allow(Sentry).to receive(:capture_message) if defined?(Sentry)
    end

    it "returns metrics and alerts" do
      result = described_class.new.perform

      expect(result).to have_key(:metrics)
      expect(result).to have_key(:alerts)
    end

    it "gathers model counts" do
      create(:user)

      result = described_class.new.perform
      metrics = result[:metrics]

      expect(metrics[:users_count]).to be >= 1
      expect(metrics).to have_key(:tasks_count)
      expect(metrics).to have_key(:lists_count)
      expect(metrics).to have_key(:devices_count)
      expect(metrics).to have_key(:jwt_denylist_count)
      expect(metrics).to have_key(:analytics_events_count)
    end

    it "includes connection pool stats" do
      result = described_class.new.perform
      pool = result[:metrics][:connection_pool]

      expect(pool).to have_key(:size)
      expect(pool).to have_key(:connections)
      expect(pool).to have_key(:available)
      expect(pool).to have_key(:usage_ratio)
      expect(pool[:usage_ratio]).to be_a(Float)
    end

    it "includes table sizes" do
      result = described_class.new.perform

      expect(result[:metrics]).to have_key(:table_sizes)
      expect(result[:metrics][:table_sizes]).to be_an(Array)
    end

    it "returns empty alerts when all thresholds are met" do
      result = described_class.new.perform

      expect(result[:alerts]).to be_an(Array)
      expect(result[:alerts]).to be_empty
    end

    context "when JWT denylist exceeds threshold" do
      before do
        stub_const("DatabaseHealthCheckJob::THRESHOLDS", described_class::THRESHOLDS.merge(jwt_denylist_max: 0))
        JwtDenylist.create!(jti: "test-1", exp: 1.day.from_now)
      end

      it "generates an alert" do
        result = described_class.new.perform

        jwt_alert = result[:alerts].find { |a| a[:metric] == "jwt_denylist_count" }
        expect(jwt_alert).to be_present
        expect(jwt_alert[:issue]).to include("JWT denylist")
      end

      it "sends alert to Sentry" do
        described_class.new.perform

        expect(Sentry).to have_received(:capture_message).with(
          /JWT denylist/,
          hash_including(level: :warning)
        )
      end
    end

    context "when analytics events exceed threshold" do
      before do
        stub_const("DatabaseHealthCheckJob::THRESHOLDS", described_class::THRESHOLDS.merge(analytics_events_max: 0))
        user = create(:user)
        AnalyticsEvent.create!(user: user, event_type: "app_opened", occurred_at: Time.current)
      end

      it "generates an alert" do
        result = described_class.new.perform

        analytics_alert = result[:alerts].find { |a| a[:metric] == "analytics_events_count" }
        expect(analytics_alert).to be_present
        expect(analytics_alert[:issue]).to include("Analytics events")
      end
    end

    context "when connection pool usage is high" do
      before do
        stub_const("DatabaseHealthCheckJob::THRESHOLDS", described_class::THRESHOLDS.merge(connection_usage_max: 0.0))
      end

      it "generates an alert" do
        result = described_class.new.perform

        pool_alert = result[:alerts].find { |a| a[:metric] == "connection_usage_ratio" }
        expect(pool_alert).to be_present
        expect(pool_alert[:issue]).to include("connection pool")
      end
    end

    it "logs the health check event" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "database_health_check"
      ))

      described_class.new.perform
    end

    it "is enqueued to the critical queue" do
      expect(described_class.new.queue_name).to eq("critical")
    end
  end
end
