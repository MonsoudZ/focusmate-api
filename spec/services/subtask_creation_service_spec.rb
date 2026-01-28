# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubtaskCreationService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:parent_task) { create(:task, list: list, creator: user, due_at: 2.days.from_now, strict_mode: true) }

  describe "#call!" do
    it "creates a subtask under the parent task" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "Sub item" }
      )

      subtask = service.call!

      expect(subtask).to be_persisted
      expect(subtask.parent_task).to eq(parent_task)
      expect(subtask.title).to eq("Sub item")
      expect(subtask.creator).to eq(user)
      expect(subtask.list).to eq(list)
    end

    it "inherits due_at and strict_mode from parent" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "Sub item" }
      )

      subtask = service.call!

      expect(subtask.due_at).to eq(parent_task.due_at)
      expect(subtask.strict_mode).to eq(parent_task.strict_mode)
    end

    it "sets status to pending" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "Sub item" }
      )

      subtask = service.call!

      expect(subtask.status).to eq("pending")
    end

    it "auto-increments position" do
      create(:task, list: list, creator: user, parent_task: parent_task, position: 0)
      create(:task, list: list, creator: user, parent_task: parent_task, position: 1)

      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "Third subtask" }
      )

      subtask = service.call!

      expect(subtask.position).to eq(2)
    end

    it "starts at position 1 when no subtasks exist" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "First subtask" }
      )

      subtask = service.call!

      expect(subtask.position).to eq(1)
    end

    it "ignores soft-deleted subtasks for position calculation" do
      create(:task, list: list, creator: user, parent_task: parent_task, position: 0, deleted_at: Time.current)

      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "New subtask" }
      )

      subtask = service.call!

      expect(subtask.position).to eq(1)
    end

    it "accepts optional note" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "Sub item", note: "Details here" }
      )

      subtask = service.call!

      expect(subtask.note).to eq("Details here")
    end

    it "raises on missing title" do
      service = described_class.new(
        parent_task: parent_task,
        user: user,
        params: { title: "" }
      )

      expect { service.call! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
