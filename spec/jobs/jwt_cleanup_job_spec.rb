# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtCleanupJob, type: :job do
  describe "#perform" do
    it "removes expired JWT tokens" do
      # Create expired tokens
      JwtDenylist.create!(jti: "expired-1", exp: 1.day.ago)
      JwtDenylist.create!(jti: "expired-2", exp: 1.hour.ago)

      # Create valid token
      JwtDenylist.create!(jti: "valid-1", exp: 1.day.from_now)

      expect { described_class.new.perform }.to change { JwtDenylist.count }.from(3).to(1)
    end

    it "returns count of removed tokens" do
      JwtDenylist.create!(jti: "expired-1", exp: 1.day.ago)
      JwtDenylist.create!(jti: "expired-2", exp: 1.hour.ago)

      result = described_class.new.perform

      expect(result).to eq(2)
    end

    it "handles empty denylist" do
      result = described_class.new.perform

      expect(result).to eq(0)
    end

    it "is enqueued to maintenance queue" do
      expect(described_class.new.queue_name).to eq("maintenance")
    end
  end
end