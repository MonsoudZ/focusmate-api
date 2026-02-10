# frozen_string_literal: true

require "rails_helper"

RSpec.describe DevicePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:device) { create(:device, user: user) }

  describe "create?" do
    it "allows any authenticated user" do
      policy = described_class.new(user, Device)
      expect(policy.create?).to be true
    end
  end

  describe "destroy?" do
    it "allows the device owner" do
      policy = described_class.new(user, device)
      expect(policy.destroy?).to be true
    end

    it "blocks other users" do
      policy = described_class.new(other_user, device)
      expect(policy.destroy?).to be false
    end
  end
end
