# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMonitor do
  describe ".track_event" do
    it "logs the event" do
      expect(Rails.logger).to receive(:info).with(hash_including(event: "user_signed_up"))

      described_class.track_event("user_signed_up", user_id: 123)
    end
  end

  describe ".track_metric" do
    it "logs the metric" do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    event: "metric",
                                                    metric: "api_latency",
                                                    value: 150
                                                  ))

      described_class.track_metric("api_latency", 150, tags: { endpoint: "/tasks" })
    end
  end

  describe ".track_timing" do
    it "measures block execution time" do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    event: "metric",
                                                    metric: "test_operation.duration_ms"
                                                  ))

      result = described_class.track_timing("test_operation") do
        sleep(0.01)
        "result"
      end

      expect(result).to eq("result")
    end
  end

  describe ".alert" do
    it "logs warning for alerts" do
      expect(Rails.logger).to receive(:warn).with(hash_including(
                                                    event: "alert",
                                                    message: "High error rate"
                                                  ))

      described_class.alert("High error rate", severity: :warning)
    end
  end

  describe ".track_error" do
    it "logs the error" do
      error = StandardError.new("Something went wrong")

      expect(Rails.logger).to receive(:error).with(hash_including(
                                                     event: "error_tracked",
                                                     error_class: "StandardError",
                                                     error_message: "Something went wrong"
                                                   ))

      described_class.track_error(error, context: "test")
    end
  end

  describe ".health_snapshot" do
    it "returns health metrics" do
      snapshot = described_class.health_snapshot

      expect(snapshot).to have_key(:timestamp)
      expect(snapshot).to have_key(:database)
      expect(snapshot).to have_key(:redis)
      expect(snapshot).to have_key(:sidekiq)
    end

    it "includes database connection info" do
      snapshot = described_class.health_snapshot

      expect(snapshot[:database]).to have_key(:connected)
      expect(snapshot[:database]).to have_key(:pool_size)
    end
  end
end
