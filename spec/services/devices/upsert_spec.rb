# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devices::Upsert do
  let(:user) { create(:user) }

  describe ".call!" do
    it "creates a device when token is new" do
      device = described_class.call!(user: user, apns_token: "abc", platform: "ios")

      expect(device).to be_persisted
      expect(device.apns_token).to eq("abc")
      expect(device.user_id).to eq(user.id)
    end

    it "is idempotent for the same user + token" do
      d1 = described_class.call!(user: user, apns_token: "abc", platform: "ios")
      d2 = described_class.call!(user: user, apns_token: "abc", platform: "ios")

      expect(d2.id).to eq(d1.id)
      expect(user.devices.where(apns_token: "abc").count).to eq(1)
    end

    it "strips whitespace from token" do
      device = described_class.call!(user: user, apns_token: "  abc  ")
      expect(device.apns_token).to eq("abc")
    end

    it "raises BadRequest when token is blank" do
      expect {
        described_class.call!(user: user, apns_token: "   ")
      }.to raise_error(Devices::Upsert::BadRequest, "apns_token is required")
    end

    it "sets last_seen_at when the model supports it" do
      device = described_class.call!(user: user, apns_token: "abc")
      if device.respond_to?(:last_seen_at)
        expect(device.last_seen_at).to be_present
      end
    end
  end
end
