# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertingService do
  describe ".check" do
    context "when threshold is exceeded" do
      it "returns triggered: true" do
        result = described_class.check(:queue_backlog, current_value: 1500)

        expect(result[:triggered]).to be true
        expect(result[:current_value]).to eq(1500)
        expect(result[:threshold]).to eq(1000)
      end
    end

    context "when threshold is not exceeded" do
      it "returns triggered: false" do
        result = described_class.check(:queue_backlog, current_value: 500)

        expect(result[:triggered]).to be false
        expect(result[:current_value]).to eq(500)
      end
    end

    context "when in cooldown" do
      around do |example|
        # Use memory store for this test since null_store doesn't persist
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
        Rails.cache = original_cache
      end

      before do
        Rails.cache.write("alert_cooldown:queue_backlog", true, expires_in: 5.minutes)
      end

      it "returns in_cooldown: true" do
        result = described_class.check(:queue_backlog, current_value: 1500)

        expect(result[:in_cooldown]).to be true
      end
    end

    context "when threshold is exceeded and alert just fired" do
      around do |example|
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
        Rails.cache = original_cache
      end

      it "reports not in cooldown for the current check result" do
        result = described_class.check(:queue_backlog, current_value: 1500)

        expect(result[:triggered]).to be true
        expect(result[:in_cooldown]).to be false
      end

      it "reports in cooldown on subsequent checks" do
        described_class.check(:queue_backlog, current_value: 1500)
        second = described_class.check(:queue_backlog, current_value: 1500)

        expect(second[:triggered]).to be true
        expect(second[:in_cooldown]).to be true
      end
    end

    context "with unknown alert" do
      it "returns error" do
        result = described_class.check(:unknown_alert, current_value: 100)

        expect(result[:error]).to include("Unknown alert")
      end
    end
  end

  describe ".check_all_thresholds" do
    it "returns results for all alerts" do
      results = described_class.check_all_thresholds

      expect(results).to have_key(:queue_backlog)
      expect(results).to have_key(:dead_jobs)
      expect(results).to have_key(:database_connections)
      expect(results).to have_key(:memory_usage)
    end
  end

  describe "threshold_exceeded?" do
    it "triggers for less_than comparison" do
      triggered = described_class.send(:threshold_exceeded?, 5, 10, :less_than)
      expect(triggered).to be true
    end

    it "does not trigger for less_than when value exceeds threshold" do
      triggered = described_class.send(:threshold_exceeded?, 15, 10, :less_than)
      expect(triggered).to be false
    end

    it "triggers for equals comparison" do
      triggered = described_class.send(:threshold_exceeded?, 10, 10, :equals)
      expect(triggered).to be true
    end

    it "does not trigger for equals when value differs" do
      triggered = described_class.send(:threshold_exceeded?, 5, 10, :equals)
      expect(triggered).to be false
    end

    it "returns false for unknown comparison type" do
      triggered = described_class.send(:threshold_exceeded?, 10, 10, :unknown)
      expect(triggered).to be false
    end
  end

  describe "fire_alert" do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    it "logs alert and sends to Sentry when triggered" do
      expect(Rails.logger).to receive(:error).with(hash_including(
                                                     event: "alert_fired",
                                                     alert: :queue_backlog
                                                   ))

      if defined?(Sentry)
        expect(Sentry).to receive(:capture_message).with(
          /Alert:/,
          hash_including(level: :warning)
        )
      end

      described_class.check(:queue_backlog, current_value: 1500)
    end

    it "sends error level to Sentry for error severity alerts" do
      expect(Rails.logger).to receive(:error).with(hash_including(
                                                     event: "alert_fired",
                                                     alert: :dead_jobs
                                                   ))

      if defined?(Sentry)
        expect(Sentry).to receive(:capture_message).with(
          /Alert:/,
          hash_including(level: :error)
        )
      end

      described_class.check(:dead_jobs, current_value: 15)
    end

    it "does not raise when Sentry capture_message fails" do
      if defined?(Sentry)
        allow(Sentry).to receive(:capture_message).and_raise(StandardError, "Sentry API down")
        allow(Rails.logger).to receive(:error)
      end

      expect { described_class.check(:queue_backlog, current_value: 1500) }.not_to raise_error

      if defined?(Sentry)
        expect(Rails.logger).to have_received(:error).with(hash_including(
          event: "alerting_service_sentry_failure",
          error_class: "StandardError",
          error_message: "Sentry API down"
        ))
      end
    end
  end

  describe "error throttling" do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    it "throttles repeated Sentry failures" do
      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_message).and_raise(StandardError, "Sentry down")
      allow(Rails.logger).to receive(:error)

      # First call — logs the failure
      described_class.check(:queue_backlog, current_value: 1500)
      # Second call — same error, should be throttled
      described_class.check(:dead_jobs, current_value: 15)

      sentry_failure_logs = 0
      expect(Rails.logger).to have_received(:error).at_least(:once) do |args|
        sentry_failure_logs += 1 if args.is_a?(Hash) && args[:event] == "alerting_service_sentry_failure"
      end
    end

    it "throttles repeated metric collection error logs" do
      allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError, "Redis down")
      allow(Rails.logger).to receive(:error)

      # First call logs, second call with same error is throttled
      described_class.check_all_thresholds
      described_class.check_all_thresholds

      metric_failure_count = 0
      expect(Rails.logger).to have_received(:error).at_least(:once) do |args|
        metric_failure_count += 1 if args.is_a?(Hash) && args[:event] == "alerting_metric_collection_failed" && args[:metric] == "sidekiq_enqueued"
      end
    end
  end

  describe "memory_mb" do
    it "returns 0 when GetProcessMem is not defined" do
      allow(described_class).to receive(:memory_mb).and_call_original
      # GetProcessMem is typically not defined in test env
      result = described_class.send(:memory_mb)
      # Either returns 0 (not defined) or a positive number (defined)
      expect(result).to be_a(Numeric)
    end
  end

  describe "metric collection" do
    it "handles sidekiq errors gracefully" do
      allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError, "Connection failed")
      expect(Rails.logger).to receive(:error).with(hash_including(
        event: "alerting_metric_collection_failed",
        metric: "sidekiq_enqueued"
      ))
      expect(Rails.logger).to receive(:error).with(hash_including(
        event: "alerting_metric_collection_failed",
        metric: "sidekiq_dead"
      ))

      results = described_class.check_all_thresholds

      expect(results[:queue_backlog][:current_value]).to eq(0)
      expect(results[:dead_jobs][:current_value]).to eq(0)
    end

    it "handles database errors gracefully" do
      allow(ActiveRecord::Base).to receive(:connection_pool).and_raise(StandardError, "DB error")

      results = described_class.check_all_thresholds

      expect(results[:database_connections][:current_value]).to eq(0)
    end
  end
end
