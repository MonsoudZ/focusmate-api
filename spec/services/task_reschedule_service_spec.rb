# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskRescheduleService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user, due_at: 1.day.from_now) }

  describe ".call!" do
    context "with valid inputs" do
      it "updates the task due date" do
        new_due = 3.days.from_now
        described_class.call!(task: task, user: user, new_due_at: new_due, reason: "blocked")

        expect(task.reload.due_at).to be_within(1.second).of(new_due)
      end

      it "creates a reschedule event" do
        expect {
          described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "priorities_shifted")
        }.to change(RescheduleEvent, :count).by(1)
      end

      it "records the previous due date" do
        original_due = task.due_at
        described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "blocked")

        event = task.reschedule_events.last
        expect(event.previous_due_at).to be_within(1.second).of(original_due)
      end

      it "records the reason" do
        described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "scope_changed")

        event = task.reschedule_events.last
        expect(event.reason).to eq("scope_changed")
      end

      it "records the user" do
        described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "blocked")

        event = task.reschedule_events.last
        expect(event.user).to eq(user)
      end

      it "returns the task" do
        result = described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "blocked")
        expect(result).to eq(task)
      end
    end

    context "when user is unauthorized" do
      it "raises Forbidden" do
        expect {
          described_class.call!(task: task, user: other_user, new_due_at: 3.days.from_now, reason: "blocked")
        }.to raise_error(ApplicationError::Forbidden)
      end

      it "does not create a reschedule event" do
        expect {
          described_class.call!(task: task, user: other_user, new_due_at: 3.days.from_now, reason: "blocked") rescue nil
        }.not_to change(RescheduleEvent, :count)
      end
    end

    context "when new_due_at is missing" do
      it "raises BadRequest" do
        expect {
          described_class.call!(task: task, user: user, new_due_at: nil, reason: "blocked")
        }.to raise_error(ApplicationError::BadRequest, "new_due_at is required")
      end
    end

    context "when reason is missing" do
      it "raises BadRequest" do
        expect {
          described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: nil)
        }.to raise_error(ApplicationError::BadRequest, "reason is required")
      end

      it "raises for blank reason" do
        expect {
          described_class.call!(task: task, user: user, new_due_at: 3.days.from_now, reason: "")
        }.to raise_error(ApplicationError::BadRequest, "reason is required")
      end
    end

    context "as list member with edit access" do
      let(:member) { create(:user) }

      before do
        create(:membership, list: list, user: member, role: "editor")
      end

      it "allows rescheduling" do
        result = described_class.call!(task: task, user: member, new_due_at: 3.days.from_now, reason: "blocked")
        expect(result.reload.due_at).to be > task.created_at
      end
    end
  end
end
