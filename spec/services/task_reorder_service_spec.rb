# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskReorderService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe "#reorder!" do
    it "updates positions for given tasks" do
      task1 = create(:task, list: list, creator: user, position: 0)
      task2 = create(:task, list: list, creator: user, position: 1)
      task3 = create(:task, list: list, creator: user, position: 2)

      service = described_class.new(list: list)
      service.reorder!([
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

      service = described_class.new(list: list)

      # Non-existent task ID should roll back all changes
      expect {
        service.reorder!([
          { id: task1.id, position: 5 },
          { id: 99999, position: 0 }
        ])
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(task1.reload.position).to eq(0) # unchanged due to rollback
    end

    it "raises RecordNotFound for tasks not in the list" do
      other_list = create(:list, user: user)
      other_task = create(:task, list: other_list, creator: user)

      service = described_class.new(list: list)

      expect {
        service.reorder!([ { id: other_task.id, position: 0 } ])
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
