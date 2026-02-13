# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendNudgeNotificationJob, type: :job do
  let(:from_user) { create(:user, name: "Alice") }
  let(:to_user) { create(:user, name: "Bob") }
  let(:list) { create(:list, user: from_user) }
  let(:task) { create(:task, list: list, creator: from_user, title: "Do homework") }
  let(:nudge) { create(:nudge, task: task, from_user: from_user, to_user: to_user) }

  describe "#perform" do
    it "sends a push notification for a valid nudge" do
      allow(PushNotifications::Sender).to receive(:send_nudge)

      described_class.new.perform(nudge_id: nudge.id)

      expect(PushNotifications::Sender).to have_received(:send_nudge).with(
        from_user: from_user,
        to_user: to_user,
        task: task
      )
    end

    it "does nothing when nudge does not exist" do
      expect(PushNotifications::Sender).not_to receive(:send_nudge)

      described_class.new.perform(nudge_id: 0)
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
