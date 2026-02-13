# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendTaskAssignedNotificationJob, type: :job do
  let(:owner) { create(:user, name: "Owner") }
  let(:assignee) { create(:user, name: "Assignee") }
  let(:list) { create(:list, user: owner) }
  let(:task) do
    create(:membership, list: list, user: assignee, role: "editor")
    create(:task, list: list, creator: owner, assigned_to: assignee)
  end

  describe "#perform" do
    it "sends a push notification for a valid task" do
      allow(PushNotifications::Sender).to receive(:send_task_assigned)

      described_class.new.perform(task_id: task.id, assigned_by_id: owner.id)

      expect(PushNotifications::Sender).to have_received(:send_task_assigned).with(
        to_user: assignee,
        task: task,
        assigned_by: owner
      )
    end

    it "does nothing when task does not exist" do
      expect(PushNotifications::Sender).not_to receive(:send_task_assigned)

      described_class.new.perform(task_id: 0, assigned_by_id: owner.id)
    end

    it "does nothing when task has no assignee" do
      task.update_columns(assigned_to_id: nil)

      expect(PushNotifications::Sender).not_to receive(:send_task_assigned)

      described_class.new.perform(task_id: task.id, assigned_by_id: owner.id)
    end

    it "does nothing when assigned_by user does not exist" do
      expect(PushNotifications::Sender).not_to receive(:send_task_assigned)

      described_class.new.perform(task_id: task.id, assigned_by_id: 0)
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
