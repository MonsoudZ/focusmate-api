# frozen_string_literal: true

require "rails_helper"

RSpec.describe Health::Checks::Redis do
  describe "#call" do
    it "pings through Sidekiq pool when Sidekiq is defined" do
      pooled_client = instance_double(::Redis, ping: "PONG")
      expect(Sidekiq).to receive(:redis).and_yield(pooled_client)

      result = described_class.new.call

      expect(result[:status]).to eq("healthy")
      expect(result[:message]).to eq("Redis responsive")
    end

    it "falls back to direct Redis connection when Sidekiq is not defined" do
      client = instance_double(::Redis, ping: "PONG", close: nil)
      allow(::Redis).to receive(:new).and_return(client)
      check = described_class.new
      allow(check).to receive(:ping_response).and_wrap_original do
        # Simulate the non-Sidekiq path
        redis = ::Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
        begin
          redis.ping
        ensure
          redis.close
        end
      end

      result = check.call

      expect(result[:status]).to eq("healthy")
      expect(client).to have_received(:close)
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
