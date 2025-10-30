require 'rails_helper'

RSpec.describe SubtaskManagementService do
  let(:list_owner) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:parent_task) { create(:task, list: list, creator: list_owner, title: 'Parent Task') }

  describe '#create_subtask!' do
    let(:default_due_at) { 1.hour.from_now }

    context 'when user is the list owner' do
      it 'creates a subtask with title' do
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.create_subtask!(title: 'Subtask 1', due_at: default_due_at)
        }.to change(Task, :count).by(1)

        subtask = Task.last
        expect(subtask.title).to eq('Subtask 1')
        expect(subtask.list_id).to eq(list.id)
        expect(subtask.creator_id).to eq(list_owner.id)
      end

      it 'creates a subtask with title and note' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        subtask = service.create_subtask!(title: 'Subtask 2', note: 'Some notes', due_at: default_due_at)

        expect(subtask.title).to eq('Subtask 2')
        expect(subtask.note).to eq('Some notes')
      end

      it 'creates a subtask with due_at' do
        due_time = 2.hours.from_now
        service = described_class.new(parent_task: parent_task, user: list_owner)
        subtask = service.create_subtask!(title: 'Subtask 3', due_at: due_time)

        expect(subtask.due_at).to be_within(1.second).of(due_time)
      end

      it 'sets strict_mode to true' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        subtask = service.create_subtask!(title: 'Subtask 4', due_at: default_due_at)

        expect(subtask.strict_mode).to be true
      end

      it 'sets parent_task_id if column exists' do
        skip 'parent_task_id column not implemented' unless Task.column_names.include?('parent_task_id')

        service = described_class.new(parent_task: parent_task, user: list_owner)
        subtask = service.create_subtask!(title: 'Subtask 5', due_at: default_due_at)

        expect(subtask.parent_task_id).to eq(parent_task.id)
      end

      it 'returns the created subtask' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        result = service.create_subtask!(title: 'Subtask 6', due_at: default_due_at)

        expect(result).to be_a(Task)
        expect(result.persisted?).to be true
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          service.create_subtask!(title: 'Unauthorized Subtask')
        }.to raise_error(SubtaskManagementService::UnauthorizedError, "Only list owner can manage subtasks")
      end

      it 'does not create a subtask' do
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          begin
            service.create_subtask!(title: 'Unauthorized Subtask')
          rescue SubtaskManagementService::UnauthorizedError
            # Expected error
          end
        }.not_to change(Task, :count)
      end
    end

    context 'when validation fails' do
      it 'raises ValidationError with details' do
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.create_subtask!(title: '') # Empty title should fail validation
        }.to raise_error(SubtaskManagementService::ValidationError) do |error|
          expect(error.message).to eq("Validation failed")
          expect(error.details).to be_a(Hash)
        end
      end

      it 'does not create a subtask on validation failure' do
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          begin
            service.create_subtask!(title: '')
          rescue SubtaskManagementService::ValidationError
            # Expected error
          end
        }.not_to change(Task, :count)
      end
    end

    context 'when due_at is required but missing' do
      before do
        # Check if due_at has presence validator
        @has_presence_validator = Task.validators_on(:due_at).any? { |v| v.kind == :presence }
      end

      it 'raises ValidationError if due_at is required' do
        skip 'due_at does not have presence validator' unless @has_presence_validator

        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.create_subtask!(title: 'Subtask without due_at', due_at: nil)
        }.to raise_error(SubtaskManagementService::ValidationError) do |error|
          expect(error.details).to have_key(:due_at)
        end
      end
    end
  end

  describe '#update_subtask!' do
    let(:subtask) { create(:task, list: list, creator: list_owner, title: 'Original Title') }

    context 'when user is the list owner' do
      it 'updates the subtask title' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        result = service.update_subtask!(subtask: subtask, attributes: { title: 'Updated Title' })

        expect(result).to eq(subtask)
        expect(subtask.reload.title).to eq('Updated Title')
      end

      it 'updates the subtask note' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        result = service.update_subtask!(subtask: subtask, attributes: { note: 'Updated note' })

        expect(result).to eq(subtask)
        expect(subtask.reload.note).to eq('Updated note')
      end

      it 'updates multiple attributes' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        service.update_subtask!(
          subtask: subtask,
          attributes: { title: 'New Title', note: 'New Note' }
        )

        subtask.reload
        expect(subtask.title).to eq('New Title')
        expect(subtask.note).to eq('New Note')
      end

      it 'returns the updated subtask' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        result = service.update_subtask!(subtask: subtask, attributes: { title: 'Test' })

        expect(result).to be_a(Task)
        expect(result).to eq(subtask)
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          service.update_subtask!(subtask: subtask, attributes: { title: 'Hacked' })
        }.to raise_error(SubtaskManagementService::UnauthorizedError, "Only list owner can manage subtasks")
      end

      it 'does not update the subtask' do
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          service.update_subtask!(subtask: subtask, attributes: { title: 'Hacked' })
        }.to raise_error(SubtaskManagementService::UnauthorizedError)

        expect(subtask.reload.title).to eq('Original Title')
      end
    end

    context 'when validation fails' do
      it 'raises ValidationError with details' do
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.update_subtask!(subtask: subtask, attributes: { title: '' })
        }.to raise_error(SubtaskManagementService::ValidationError) do |error|
          expect(error.message).to eq("Validation failed")
          expect(error.details).to be_a(Hash)
        end
      end

      it 'does not update the subtask on validation failure' do
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.update_subtask!(subtask: subtask, attributes: { title: '' })
        }.to raise_error(SubtaskManagementService::ValidationError)

        expect(subtask.reload.title).to eq('Original Title')
      end
    end
  end

  describe '#delete_subtask!' do
    let(:subtask) { create(:task, list: list, creator: list_owner) }

    context 'when user is the list owner' do
      it 'deletes the subtask' do
        subtask # Ensure it exists
        service = described_class.new(parent_task: parent_task, user: list_owner)

        expect {
          service.delete_subtask!(subtask: subtask)
        }.to change(Task, :count).by(-1)
      end

      it 'returns true' do
        service = described_class.new(parent_task: parent_task, user: list_owner)
        result = service.delete_subtask!(subtask: subtask)

        expect(result).to be true
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          service.delete_subtask!(subtask: subtask)
        }.to raise_error(SubtaskManagementService::UnauthorizedError, "Only list owner can manage subtasks")
      end

      it 'does not delete the subtask' do
        subtask # Ensure it exists
        service = described_class.new(parent_task: parent_task, user: unauthorized_user)

        expect {
          begin
            service.delete_subtask!(subtask: subtask)
          rescue SubtaskManagementService::UnauthorizedError
            # Expected error
          end
        }.not_to change(Task, :count)
      end
    end
  end

  describe 'ValidationError' do
    it 'stores details hash' do
      error = SubtaskManagementService::ValidationError.new("Test message", { field: [ "error" ] })

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({ field: [ "error" ] })
    end

    it 'handles empty details' do
      error = SubtaskManagementService::ValidationError.new("Test message")

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({})
    end
  end
end
