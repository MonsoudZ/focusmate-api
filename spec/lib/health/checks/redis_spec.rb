# frozen_string_literal: true

require "rails_helper"

RSpec.describe Health::Checks::Redis do
  describe "#call" do
    it "uses Redis.current when available" do
      client = instance_double(::Redis, ping: "PONG")
      allow(Redis).to receive(:respond_to?).and_call_original
      allow(Redis).to receive(:respond_to?).with(:current).and_return(true)
      without_partial_double_verification do
        allow(Redis).to receive(:current).and_return(client)
      end

      result = described_class.new.call

      expect(result[:status]).to eq("healthy")
      expect(result[:message]).to eq("Redis responsive")
    end

    it "pings through Sidekiq pool when Redis.current is unavailable" do
      pooled_client = instance_double(::Redis, ping: "PONG")
      allow(Redis).to receive(:respond_to?).and_call_original
      allow(Redis).to receive(:respond_to?).with(:current).and_return(false)
      expect(Sidekiq).to receive(:redis).and_yield(pooled_client)

      result = described_class.new.call

      expect(result[:status]).to eq("healthy")
    end

    it "returns unhealthy when ping response is unexpected" do
      check = described_class.new
      allow(check).to receive(:ping_response).and_return("NOPE")

      result = check.call

      expect(result[:status]).to eq("unhealthy")
      expect(result[:message]).to include("Unexpected response")
    end
  end
end
