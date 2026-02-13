# frozen_string_literal: true

require "rails_helper"

RSpec.describe FriendshipPolicy, type: :policy do
  let(:user) { create(:user) }

  # FriendshipPolicy is a headless policy — the controller passes :friendship
  # as the record. All actions return true because the controller already
  # scopes queries through current_user.friends.

  describe "index?" do
    it "allows any authenticated user" do
      policy = described_class.new(user, :friendship)
      expect(policy.index?).to be true
    end
  end

  describe "destroy?" do
    it "allows any authenticated user" do
      policy = described_class.new(user, :friendship)
      expect(policy.destroy?).to be true
    end
  end
end
