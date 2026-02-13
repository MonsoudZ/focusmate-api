# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendListJoinedNotificationJob, type: :job do
  let(:owner) { create(:user, name: "Owner") }
  let(:new_member) { create(:user, name: "New Member") }
  let(:list) { create(:list, user: owner) }

  describe "#perform" do
    it "sends a push notification for a valid list join" do
      allow(PushNotifications::Sender).to receive(:send_list_joined)

      described_class.new.perform(list_id: list.id, new_member_id: new_member.id)

      expect(PushNotifications::Sender).to have_received(:send_list_joined).with(
        to_user: owner,
        new_member: new_member,
        list: list
      )
    end

    it "does nothing when list does not exist" do
      expect(PushNotifications::Sender).not_to receive(:send_list_joined)

      described_class.new.perform(list_id: 0, new_member_id: new_member.id)
    end

    it "does nothing when new member does not exist" do
      expect(PushNotifications::Sender).not_to receive(:send_list_joined)

      described_class.new.perform(list_id: list.id, new_member_id: 0)
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
