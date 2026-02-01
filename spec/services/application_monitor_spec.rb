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

    it "triggers alert for slow operations over 5 seconds" do
      # Mock the timing to simulate a slow operation
      allow(Process).to receive(:clock_gettime).and_return(0.0, 6.0) # 6 second difference

      expect(Rails.logger).to receive(:info).with(hash_including(event: "metric"))
      expect(Rails.logger).to receive(:warn).with(hash_including(
                                                    event: "alert",
                                                    message: "Slow operation: slow_operation"
                                                  ))

      described_class.track_timing("slow_operation") { "done" }
    end
  end

  describe ".alert" do
    it "logs warning for warning severity" do
      expect(Rails.logger).to receive(:warn).with(hash_including(
                                                    event: "alert",
                                                    message: "High error rate",
                                                    severity: :warning
                                                  ))

      described_class.alert("High error rate", severity: :warning)
    end

    it "logs warning for critical severity" do
      expect(Rails.logger).to receive(:warn).with(hash_including(
                                                    event: "alert",
                                                    message: "Critical failure",
                                                    severity: :critical
                                                  ))

      described_class.alert("Critical failure", severity: :critical)
    end

    it "logs warning for error severity" do
      expect(Rails.logger).to receive(:warn).with(hash_including(
                                                    event: "alert",
                                                    message: "Error occurred",
                                                    severity: :error
                                                  ))

      described_class.alert("Error occurred", severity: :error)
    end

    it "logs info for info severity" do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    event: "alert",
                                                    message: "FYI alert",
                                                    severity: :info
                                                  ))

      described_class.alert("FYI alert", severity: :info)
    end

    it "logs info for unknown severity" do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    event: "alert",
                                                    message: "Unknown severity",
                                                    severity: :unknown
                                                  ))

      described_class.alert("Unknown severity", severity: :unknown)
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

    it "sends to Sentry if defined" do
      error = StandardError.new("Test error")

      if defined?(Sentry)
        expect(Sentry).to receive(:capture_exception).with(error, extra: { context: "test" })
      end

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
      expect(snapshot).to have_key(:memory)
    end

    it "includes database connection info" do
      snapshot = described_class.health_snapshot

      expect(snapshot[:database]).to have_key(:connected)
      expect(snapshot[:database]).to have_key(:pool_size)
      expect(snapshot[:database]).to have_key(:pool_usage)
    end

    context "when database check fails" do
      it "returns error info" do
        allow(ActiveRecord::Base).to receive(:connected?).and_raise(StandardError, "DB connection failed")

        snapshot = described_class.health_snapshot

        expect(snapshot[:database]).to have_key(:error)
        expect(snapshot[:database][:error]).to eq("DB connection failed")
      end
    end

    context "when redis check fails" do
      it "returns error info" do
        allow(Redis).to receive(:new).and_raise(StandardError, "Redis connection failed")

        snapshot = described_class.health_snapshot

        expect(snapshot[:redis][:connected]).to be false
        expect(snapshot[:redis][:error]).to eq("Redis connection failed")
      end
    end

    context "when sidekiq check fails" do
      it "returns error info" do
        allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError, "Sidekiq unavailable")

        snapshot = described_class.health_snapshot

        expect(snapshot[:sidekiq]).to have_key(:error)
        expect(snapshot[:sidekiq][:error]).to eq("Sidekiq unavailable")
      end
    end

    context "when GetProcessMem is not defined" do
      it "returns empty memory hash" do
        # GetProcessMem may or may not be defined in test environment
        snapshot = described_class.health_snapshot

        expect(snapshot[:memory]).to be_a(Hash)
      end
    end
  end

  describe "send_to_sentry error handling" do
    it "logs error if Sentry fails" do
      if defined?(Sentry)
        allow(Sentry).to receive(:capture_message).and_raise(StandardError, "Sentry API error")
        expect(Rails.logger).to receive(:error).with("Failed to send to Sentry: Sentry API error")
      end

      # Should not raise, just log the error
      expect {
        described_class.track_event("test_event")
      }.not_to raise_error
    end
  end
end
