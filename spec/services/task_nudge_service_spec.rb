# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskNudgeService do
  let(:from_user) { create(:user, name: "Alice") }
  let(:task_owner) { create(:user, name: "Bob") }
  let(:list) { create(:list, user: task_owner) }
  let(:task) { create(:task, list: list, creator: task_owner, title: "Do homework") }

  describe "#call!" do
    before do
      allow(PushNotifications::Sender).to receive(:send_nudge)
    end

    it "creates a nudge record" do
      service = described_class.new(task: task, from_user: from_user)

      expect { service.call! }.to change(Nudge, :count).by(1)
    end

    it "sends a push notification" do
      service = described_class.new(task: task, from_user: from_user)
      service.call!

      expect(PushNotifications::Sender).to have_received(:send_nudge).with(
        from_user: from_user,
        to_user: task_owner,
        task: task
      )
    end

    it "returns the nudge" do
      service = described_class.new(task: task, from_user: from_user)
      result = service.call!

      expect(result).to be_a(Nudge)
      expect(result).to be_persisted
    end

    it "raises SelfNudge when nudging yourself" do
      service = described_class.new(task: task, from_user: task_owner)

      expect {
        service.call!
      }.to raise_error(ApplicationError::UnprocessableEntity, "You cannot nudge yourself")
    end

    it "sends nudge to task creator" do
      service = described_class.new(task: task, from_user: from_user)
      service.call!

      expect(PushNotifications::Sender).to have_received(:send_nudge).with(
        hash_including(to_user: task_owner)
      )
    end
  end
end
