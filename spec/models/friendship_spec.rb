# frozen_string_literal: true

require "rails_helper"

RSpec.describe Friendship, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:friend).class_name("User") }
  end

  describe "validations" do
    it "validates uniqueness of user_id scoped to friend_id" do
      existing = create(:friendship)
      duplicate = build(:friendship, user: existing.user, friend: existing.friend)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("is already friends with this user")
    end

    it "prevents friending yourself" do
      user = create(:user)
      friendship = build(:friendship, user: user, friend: user)
      expect(friendship).not_to be_valid
      expect(friendship.errors[:friend]).to include("can't be yourself")
    end
  end

  describe ".create_mutual!" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }

    it "creates friendships in both directions" do
      expect {
        described_class.create_mutual!(user_a, user_b)
      }.to change(Friendship, :count).by(2)
    end

    it "makes both users friends with each other" do
      described_class.create_mutual!(user_a, user_b)

      expect(user_a.friends).to include(user_b)
      expect(user_b.friends).to include(user_a)
    end

    it "is idempotent - raises on duplicate" do
      described_class.create_mutual!(user_a, user_b)

      expect {
        described_class.create_mutual!(user_a, user_b)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".destroy_mutual!" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }

    before do
      described_class.create_mutual!(user_a, user_b)
    end

    it "removes friendships in both directions" do
      expect {
        described_class.destroy_mutual!(user_a, user_b)
      }.to change(Friendship, :count).by(-2)
    end

    it "removes both users from each other's friends" do
      described_class.destroy_mutual!(user_a, user_b)

      expect(user_a.reload.friends).not_to include(user_b)
      expect(user_b.reload.friends).not_to include(user_a)
    end
  end

  describe ".friends?" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let(:user_c) { create(:user) }

    before do
      described_class.create_mutual!(user_a, user_b)
    end

    it "returns true for friends" do
      expect(described_class.friends?(user_a, user_b)).to be true
      expect(described_class.friends?(user_b, user_a)).to be true
    end

    it "returns false for non-friends" do
      expect(described_class.friends?(user_a, user_c)).to be false
    end
  end
end
