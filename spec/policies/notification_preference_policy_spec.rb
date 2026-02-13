# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPreferencePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:preference) { create(:notification_preference, user: user) }

  describe "#show?" do
    it "allows owner to view" do
      policy = described_class.new(user, preference)
      expect(policy.show?).to be true
    end

    it "denies other users from viewing" do
      policy = described_class.new(other_user, preference)
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(user, NotificationPreference.new)
      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "allows owner to update" do
      policy = described_class.new(user, preference)
      expect(policy.update?).to be true
    end

    it "denies other users from updating" do
      policy = described_class.new(other_user, preference)
      expect(policy.update?).to be false
    end
  end
end
