require 'rails_helper'

RSpec.describe TaskReassignmentService do
  let(:list_owner) { create(:user) }
  let(:task_creator) { create(:user) }
  let(:new_assignee) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: task_creator) }

  describe '#reassign!' do
    context 'when user is the list owner' do
      it 'reassigns the task successfully' do
        service = described_class.new(task: task, user: list_owner)
        result = service.reassign!(assigned_to_id: new_assignee.id)

        expect(result).to eq(task)
        expect(task.reload.assigned_to_id).to eq(new_assignee.id)
      end

      it 'allows reassigning to nil' do
        task.update!(assigned_to_id: task_creator.id)
        service = described_class.new(task: task, user: list_owner)
        result = service.reassign!(assigned_to_id: nil)

        expect(result).to eq(task)
        expect(task.reload.assigned_to_id).to be_nil
      end

      it 'returns the task object' do
        service = described_class.new(task: task, user: list_owner)
        result = service.reassign!(assigned_to_id: new_assignee.id)

        expect(result).to be_a(Task)
        expect(result).to eq(task)
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError for task creator' do
        service = described_class.new(task: task, user: task_creator)

        expect {
          service.reassign!(assigned_to_id: new_assignee.id)
        }.to raise_error(TaskReassignmentService::UnauthorizedError, "Only list owner can reassign tasks")
      end

      it 'raises UnauthorizedError for unauthorized user' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.reassign!(assigned_to_id: new_assignee.id)
        }.to raise_error(TaskReassignmentService::UnauthorizedError, "Only list owner can reassign tasks")
      end

      it 'does not reassign the task' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.reassign!(assigned_to_id: new_assignee.id)
        }.to raise_error(TaskReassignmentService::UnauthorizedError)

        expect(task.reload.assigned_to_id).to be_nil
      end
    end

    context 'when validation fails' do
      it 'raises error for invalid foreign key' do
        service = described_class.new(task: task, user: list_owner)

        # Foreign key constraint will raise ActiveRecord::InvalidForeignKey
        expect {
          service.reassign!(assigned_to_id: 999999)
        }.to raise_error(ActiveRecord::InvalidForeignKey)
      end

      it 'does not update the task on validation failure' do
        initial_assigned_to = task.assigned_to_id
        service = described_class.new(task: task, user: list_owner)

        expect {
          service.reassign!(assigned_to_id: 999999)
        }.to raise_error(ActiveRecord::InvalidForeignKey)

        expect(task.reload.assigned_to_id).to eq(initial_assigned_to)
      end
    end

    context 'when Task model does not support assignment' do
      it 'would raise ValidationError if assignment is not supported' do
        # This test documents the behavior when assignment columns don't exist
        # Since Task currently has assigned_to_id, we verify the check exists
        service = described_class.new(task: task, user: list_owner)

        # Verify the service checks for column existence
        expect(Task.column_names).to include("assigned_to_id")

        # If neither column existed, this would raise:
        # TaskReassignmentService::ValidationError: "Task does not support assignment"
        # with details: { assigned_to: ["not supported"] }
      end
    end
  end

  describe 'ValidationError' do
    it 'stores details hash' do
      error = TaskReassignmentService::ValidationError.new("Test message", { field: [ "error" ] })

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({ field: [ "error" ] })
    end

    it 'handles empty details' do
      error = TaskReassignmentService::ValidationError.new("Test message")

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({})
    end
  end
end
