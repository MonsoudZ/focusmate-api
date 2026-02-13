# frozen_string_literal: true

require "rails_helper"

RSpec.describe RescheduleEvent do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe "validations" do
    it "requires reason" do
      event = build(:reschedule_event, task: task, reason: nil)
      expect(event).not_to be_valid
    end

    it "requires new_due_at" do
      event = build(:reschedule_event, task: task, new_due_at: nil)
      expect(event).not_to be_valid
    end

    it "is valid with all required attributes" do
      event = build(:reschedule_event, task: task, reason: "blocked", new_due_at: 1.day.from_now)
      expect(event).to be_valid
    end
  end

  describe "associations" do
    it "belongs to task" do
      event = create(:reschedule_event, task: task)
      expect(event.task).to eq(task)
    end

    it "optionally belongs to user" do
      event = create(:reschedule_event, task: task, user: user)
      expect(event.user).to eq(user)
    end

    it "is valid without a user" do
      event = build(:reschedule_event, task: task, user: nil)
      expect(event).to be_valid
    end
  end

  describe "scopes" do
    it ".recent_first orders by created_at descending" do
      old_event = create(:reschedule_event, task: task, created_at: 2.days.ago)
      new_event = create(:reschedule_event, task: task, created_at: 1.hour.ago)

      results = RescheduleEvent.recent_first
      expect(results.first).to eq(new_event)
      expect(results.last).to eq(old_event)
    end
  end

  describe "constants" do
    it "defines predefined reasons" do
      expect(RescheduleEvent::PREDEFINED_REASONS).to include("blocked", "scope_changed", "priorities_shifted")
    end
  end
end
