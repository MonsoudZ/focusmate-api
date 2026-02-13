# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubtaskSerializer do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:parent_task) { create(:task, list: list, creator: user) }
  let(:subtask) do
    create(:task,
      list: list,
      creator: user,
      parent_task_id: parent_task.id,
      title: "Buy groceries",
      note: "From the store",
      position: 1)
  end

  describe "#as_json" do
    it "serializes subtask attributes" do
      json = described_class.new(subtask).as_json

      expect(json[:id]).to eq(subtask.id)
      expect(json[:parent_task_id]).to eq(parent_task.id)
      expect(json[:title]).to eq("Buy groceries")
      expect(json[:note]).to eq("From the store")
      expect(json[:status]).to eq("pending")
      expect(json[:position]).to eq(1)
      expect(json[:created_at]).to eq(subtask.created_at)
      expect(json[:updated_at]).to eq(subtask.updated_at)
    end

    it "returns nil completed_at for non-done tasks" do
      json = described_class.new(subtask).as_json

      expect(json[:completed_at]).to be_nil
    end

    it "returns completed_at for done tasks" do
      subtask.update!(status: "done", completed_at: Time.current)
      json = described_class.new(subtask).as_json

      expect(json[:completed_at]).to eq(subtask.completed_at)
    end

    it "falls back to updated_at when completed_at is nil for done tasks" do
      subtask.update!(status: "done")
      subtask.update_column(:completed_at, nil)
      json = described_class.new(subtask.reload).as_json

      expect(json[:completed_at]).to eq(subtask.updated_at)
    end
  end
end
