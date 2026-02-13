# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid with default attributes" do
      pref = build(:notification_preference, user: user)
      expect(pref).to be_valid
    end

    it "enforces user uniqueness" do
      create(:notification_preference, user: user)
      duplicate = build(:notification_preference, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user]).to include("has already been taken")
    end

    it "requires user" do
      pref = build(:notification_preference, user: nil)
      expect(pref).not_to be_valid
    end

    NotificationPreference::NOTIFICATION_TYPES.each do |type|
      it "rejects nil for #{type}_enabled" do
        pref = build(:notification_preference, user: user, "#{type}_enabled": nil)
        expect(pref).not_to be_valid
        expect(pref.errors[:"#{type}_enabled"]).to include("is not included in the list")
      end
    end
  end

  describe "associations" do
    it "belongs to user" do
      pref = create(:notification_preference, user: user)
      expect(pref.user).to eq(user)
    end

    it "is destroyed when user is destroyed" do
      create(:notification_preference, user: user)
      expect { user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "#enabled_for?" do
    let(:pref) { create(:notification_preference, user: user, nudge_enabled: false) }

    it "returns the value of the given notification type" do
      expect(pref.enabled_for?(:nudge)).to be false
      expect(pref.enabled_for?(:task_assigned)).to be true
      expect(pref.enabled_for?(:list_joined)).to be true
      expect(pref.enabled_for?(:task_reminder)).to be true
    end
  end

  describe ".enabled_for_user?" do
    it "returns true when no preference record exists" do
      expect(described_class.enabled_for_user?(user, :nudge)).to be true
    end

    it "returns the stored value when a preference record exists" do
      create(:notification_preference, user: user, nudge_enabled: false)
      expect(described_class.enabled_for_user?(user, :nudge)).to be false
      expect(described_class.enabled_for_user?(user, :task_assigned)).to be true
    end
  end
end
