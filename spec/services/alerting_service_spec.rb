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
    end
  end
end
