# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskReorderService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe "#call!" do
    it "updates positions for given tasks" do
      task1 = create(:task, list: list, creator: user, position: 0)
      task2 = create(:task, list: list, creator: user, position: 1)
      task3 = create(:task, list: list, creator: user, position: 2)

      described_class.call!(list: list, task_positions: [
        { id: task3.id, position: 0 },
        { id: task1.id, position: 1 },
        { id: task2.id, position: 2 }
      ])

      expect(task3.reload.position).to eq(0)
      expect(task1.reload.position).to eq(1)
      expect(task2.reload.position).to eq(2)
    end

    it "wraps updates in a transaction" do
      task1 = create(:task, list: list, creator: user, position: 0)

      # Non-existent task ID should roll back all changes
      expect {
        described_class.call!(list: list, task_positions: [
          { id: task1.id, position: 5 },
          { id: 99999, position: 0 }
        ])
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(task1.reload.position).to eq(0) # unchanged due to rollback
    end

    it "raises RecordNotFound for tasks not in the list" do
      other_list = create(:list, user: user)
      other_task = create(:task, list: other_list, creator: user)

      expect {
        described_class.call!(list: list, task_positions: [ { id: other_task.id, position: 0 } ])
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises BadRequest for negative positions" do
      task = create(:task, list: list, creator: user, position: 0)

      expect {
        described_class.call!(list: list, task_positions: [ { id: task.id, position: -1 } ])
      }.to raise_error(ApplicationError::BadRequest, /Invalid position value/)
    end

    it "raises BadRequest for non-integer positions" do
      task = create(:task, list: list, creator: user, position: 0)

      expect {
        described_class.call!(list: list, task_positions: [ { id: task.id, position: "abc" } ])
      }.to raise_error(ApplicationError::BadRequest, /Invalid position value/)
    end

    it "raises BadRequest for invalid task ids" do
      expect {
        described_class.call!(list: list, task_positions: [ { id: "abc", position: 0 } ])
      }.to raise_error(ApplicationError::BadRequest, /Invalid task id/)
    end

    it "accepts zero as a valid position" do
      task = create(:task, list: list, creator: user, position: 5)

      described_class.call!(list: list, task_positions: [ { id: task.id, position: 0 } ])

      expect(task.reload.position).to eq(0)
    end

    it "raises BadRequest for duplicate task ids" do
      task = create(:task, list: list, creator: user, position: 0)

      expect {
        described_class.call!(
          list: list,
          task_positions: [
            { id: task.id, position: 1 },
            { id: task.id, position: 2 }
          ]
        )
      }.to raise_error(ApplicationError::BadRequest, /Duplicate task ids/)
    end

    it "raises BadRequest for duplicate positions" do
      task1 = create(:task, list: list, creator: user, position: 0)
      task2 = create(:task, list: list, creator: user, position: 1)

      expect {
        described_class.call!(
          list: list,
          task_positions: [
            { id: task1.id, position: 2 },
            { id: task2.id, position: 2 }
          ]
        )
      }.to raise_error(ApplicationError::BadRequest, /Duplicate positions/)
    end

    it "updates updated_at when reordering" do
      task = create(:task, list: list, creator: user, position: 0)
      old_updated_at = task.updated_at

      travel 2.seconds do
        described_class.call!(list: list, task_positions: [ { id: task.id, position: 1 } ])
      end

      expect(task.reload.updated_at).to be > old_updated_at
    end
  end
end
