# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviceSerializer do
  let(:user) { create(:user) }
  let(:device) do
    create(:device,
      user: user,
      platform: "ios",
      bundle_id: "com.focusmate.app",
      device_name: "iPhone 15",
      os_version: "18.0",
      app_version: "2.1.0")
  end

  describe "#as_json" do
    it "serializes device attributes" do
      json = described_class.new(device).as_json

      expect(json[:id]).to eq(device.id)
      expect(json[:platform]).to eq("ios")
      expect(json[:bundle_id]).to eq("com.focusmate.app")
      expect(json[:device_name]).to eq("iPhone 15")
      expect(json[:os_version]).to eq("18.0")
      expect(json[:app_version]).to eq("2.1.0")
      expect(json[:active]).to be true
      expect(json[:last_seen_at]).to eq(device.last_seen_at)
      expect(json[:created_at]).to eq(device.created_at)
      expect(json[:updated_at]).to eq(device.updated_at)
    end
  end
end
