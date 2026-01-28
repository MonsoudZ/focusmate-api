# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertingCheckJob, type: :job do
  describe "#perform" do
    let(:all_clear) do
      {
        error_rate: { triggered: false, in_cooldown: false },
        latency: { triggered: false, in_cooldown: false }
      }
    end

    let(:triggered_results) do
      {
        error_rate: { triggered: true, in_cooldown: false, value: 0.15 },
        latency: { triggered: false, in_cooldown: false },
        queue_depth: { triggered: true, in_cooldown: true, value: 500 }
      }
    end

    it "calls AlertingService.check_all_thresholds" do
      allow(AlertingService).to receive(:check_all_thresholds).and_return(all_clear)

      described_class.new.perform

      expect(AlertingService).to have_received(:check_all_thresholds)
    end

    it "returns the results hash" do
      allow(AlertingService).to receive(:check_all_thresholds).and_return(all_clear)

      result = described_class.new.perform

      expect(result).to eq(all_clear)
    end

    it "logs check results" do
      allow(AlertingService).to receive(:check_all_thresholds).and_return(triggered_results)

      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "alerting_check_completed",
        total_checks: 3,
        triggered_count: 1 # only error_rate: triggered && !in_cooldown
      ))

      described_class.new.perform
    end

    it "filters triggered alerts excluding those in cooldown" do
      allow(AlertingService).to receive(:check_all_thresholds).and_return(triggered_results)
      allow(Rails.logger).to receive(:info)

      expect(Rails.logger).to receive(:info).with(hash_including(
        triggered_count: 1
      ))

      described_class.new.perform
    end

    it "is enqueued to the critical queue" do
      expect(described_class.new.queue_name).to eq("critical")
    end
  end
end
