# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPreferenceSerializer do
  let(:user) { create(:user) }
  let(:preference) { create(:notification_preference, user: user, nudge_enabled: false) }

  describe ".one" do
    it "serializes preference attributes" do
      json = described_class.one(preference)

      expect(json[:nudge_enabled]).to be false
      expect(json[:task_assigned_enabled]).to be true
      expect(json[:list_joined_enabled]).to be true
      expect(json[:task_reminder_enabled]).to be true
      expect(json[:updated_at]).to eq(preference.updated_at)
    end

    it "returns exactly five keys" do
      json = described_class.one(preference)

      expect(json.keys).to match_array(%i[nudge_enabled task_assigned_enabled list_joined_enabled task_reminder_enabled updated_at])
    end

    it "does not expose id or user_id" do
      json = described_class.one(preference)

      expect(json).not_to have_key(:id)
      expect(json).not_to have_key(:user_id)
    end
  end
end
