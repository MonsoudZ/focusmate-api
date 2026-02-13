# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskNudgeService do
  let(:list_owner) { create(:user, name: "Owner") }
  let(:member1) { create(:user, name: "Alice") }
  let(:member2) { create(:user, name: "Bob") }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: list_owner, title: "Do homework") }

  before do
    allow(PushNotifications::Sender).to receive(:send_nudge)
  end

  describe "#call!" do
    context "with a shared list" do
      before do
        list.add_member!(member1, "editor")
        list.add_member!(member2, "viewer")
      end

      it "creates a nudge record for each recipient" do
        service = described_class.new(task: task, from_user: member1)

        # member1 nudges, so list_owner and member2 should receive nudges
        expect { service.call! }.to change(Nudge, :count).by(2)
      end

      it "sends push notifications to all recipients" do
        service = described_class.new(task: task, from_user: member1)
        service.call!

        expect(PushNotifications::Sender).to have_received(:send_nudge).with(
          from_user: member1,
          to_user: list_owner,
          task: task
        )
        expect(PushNotifications::Sender).to have_received(:send_nudge).with(
          from_user: member1,
          to_user: member2,
          task: task
        )
      end

      it "does not send a nudge to the sender" do
        service = described_class.new(task: task, from_user: member1)
        service.call!

        expect(PushNotifications::Sender).not_to have_received(:send_nudge).with(
          hash_including(to_user: member1)
        )
      end

      it "returns an array of nudges" do
        service = described_class.new(task: task, from_user: member1)
        result = service.call!

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result).to all(be_a(Nudge))
        expect(result).to all(be_persisted)
      end
    end

    context "with rate limiting" do
      before do
        list.add_member!(member1, "editor")
        list.add_member!(member2, "viewer")
      end

      it "skips recipients who were recently nudged but nudges others" do
        # Create a recent nudge to owner only
        create(:nudge, task: task, from_user: member1, to_user: list_owner, created_at: 5.minutes.ago)

        service = described_class.new(task: task, from_user: member1)

        # Should only create nudge for member2 (owner was recently nudged)
        expect { service.call! }.to change(Nudge, :count).by(1)

        expect(PushNotifications::Sender).to have_received(:send_nudge).with(
          from_user: member1,
          to_user: member2,
          task: task
        )
        expect(PushNotifications::Sender).not_to have_received(:send_nudge).with(
          hash_including(to_user: list_owner)
        )
      end

      it "allows nudging after the rate limit window" do
        # Create an old nudge to owner (outside the 10 minute window but inside 1 hour)
        # Note: Nudge model has separate rate limit of 3 per task per hour
        create(:nudge, task: task, from_user: member1, to_user: list_owner, created_at: 15.minutes.ago)

        service = described_class.new(task: task, from_user: member1)

        # Should nudge both recipients (owner again since >10min, and member2 for first time)
        expect { service.call! }.to change(Nudge, :count).by(2)
      end

      it "raises error when all recipients are rate limited" do
        # Rate limit both recipients
        create(:nudge, task: task, from_user: member1, to_user: list_owner, created_at: 5.minutes.ago)
        create(:nudge, task: task, from_user: member1, to_user: member2, created_at: 5.minutes.ago)

        service = described_class.new(task: task, from_user: member1)

        expect {
          service.call!
        }.to raise_error(ApplicationError::UnprocessableEntity, /recently nudged/)
      end
    end

    context "when the sender is the only list member" do
      it "raises an error" do
        service = described_class.new(task: task, from_user: list_owner)

        expect {
          service.call!
        }.to raise_error(ApplicationError::UnprocessableEntity, /only member/)
      end
    end

    context "with a private list (no other members)" do
      let(:private_list) { create(:list, user: list_owner, visibility: "private") }
      let(:private_task) { create(:task, list: private_list, creator: list_owner) }

      it "raises an error when owner tries to nudge" do
        service = described_class.new(task: private_task, from_user: list_owner)

        expect {
          service.call!
        }.to raise_error(ApplicationError::UnprocessableEntity, /only member/)
      end
    end

    context "with a hidden task (private_task visibility)" do
      let(:hidden_task) { create(:task, list: list, creator: list_owner, visibility: :private_task) }

      before do
        list.add_member!(member1, "editor")
        list.add_member!(member2, "viewer")
      end

      it "raises no recipients error" do
        service = described_class.new(task: hidden_task, from_user: list_owner)

        expect {
          service.call!
        }.to raise_error(ApplicationError::UnprocessableEntity, /only member/)
      end

      it "does not send any notifications" do
        service = described_class.new(task: hidden_task, from_user: list_owner)

        expect {
          service.call!
        }.to raise_error(ApplicationError::UnprocessableEntity)

        expect(PushNotifications::Sender).not_to have_received(:send_nudge)
      end
    end
  end
end
