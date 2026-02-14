# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devices::Upsert do
  let(:user) { create(:user) }

  describe ".call!" do
    let(:valid_attrs) { { platform: "ios", bundle_id: "com.intentia.app" } }

    it "creates a device when token is new" do
      device = described_class.call!(user: user, apns_token: "abc", **valid_attrs)

      expect(device).to be_persisted
      expect(device.apns_token).to eq("abc")
      expect(device.user_id).to eq(user.id)
    end

    it "is idempotent for the same user + token" do
      d1 = described_class.call!(user: user, apns_token: "abc", **valid_attrs)
      d2 = described_class.call!(user: user, apns_token: "abc", **valid_attrs)

      expect(d2.id).to eq(d1.id)
      expect(user.devices.where(apns_token: "abc").count).to eq(1)
    end

    it "strips whitespace from token" do
      device = described_class.call!(user: user, apns_token: "  abc  ", **valid_attrs)
      expect(device.apns_token).to eq("abc")
    end

    it "raises BadRequest when token is blank" do
      expect {
        described_class.call!(user: user, apns_token: "   ")
      }.to raise_error(ApplicationError::BadRequest, "apns_token is required")
    end

    it "sets last_seen_at when the model supports it" do
      device = described_class.call!(user: user, apns_token: "abc", **valid_attrs)
      if device.respond_to?(:last_seen_at)
        expect(device.last_seen_at).to be_present
      end
    end

    it "restores a soft-deleted device instead of failing on unique index" do
      device = described_class.call!(user: user, apns_token: "restore-me", **valid_attrs)
      device.soft_delete!
      expect(device.reload.deleted?).to be true

      restored = described_class.call!(user: user, apns_token: "restore-me", **valid_attrs)
      expect(restored.id).to eq(device.id)
      expect(restored.deleted?).to be false
      expect(restored.last_seen_at).to be_present
    end
  end
end
