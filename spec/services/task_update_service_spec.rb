require 'rails_helper'

RSpec.describe TaskUpdateService do
  let(:list_owner) { create(:user) }
  let(:task_creator) { create(:user) }
  let(:list_editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: task_creator, title: 'Original Title') }

  before do
    # Create editor membership
    if list.respond_to?(:memberships)
      create(:membership, list: list, user: list_editor, role: 'editor')
    end
  end

  describe '#update!' do
    context 'when user is the list owner' do
      it 'updates the task successfully' do
        service = described_class.new(task: task, user: list_owner)
        result = service.call!(attributes: { title: 'Updated Title' })

        expect(result).to eq(task)
        expect(task.reload.title).to eq('Updated Title')
      end

      it 'updates multiple attributes' do
        service = described_class.new(task: task, user: list_owner)
        service.call!(attributes: {
          title: 'New Title',
          note: 'New Note',
          strict_mode: false
        })

        task.reload
        expect(task.title).to eq('New Title')
        expect(task.note).to eq('New Note')
        expect(task.strict_mode).to be false
      end

      it 'returns the task object' do
        service = described_class.new(task: task, user: list_owner)
        result = service.call!(attributes: { title: 'Test' })

        expect(result).to be_a(Task)
        expect(result).to eq(task)
      end
    end

    context 'when user is the task creator' do
      it 'updates the task successfully' do
        service = described_class.new(task: task, user: task_creator)
        result = service.call!(attributes: { title: 'Creator Updated' })

        expect(result).to eq(task)
        expect(task.reload.title).to eq('Creator Updated')
      end
    end

    context 'when user is a list editor' do
      it 'updates the task successfully' do
        skip 'List memberships not implemented' unless list.respond_to?(:memberships)

        service = described_class.new(task: task, user: list_editor)
        result = service.call!(attributes: { title: 'Editor Updated' })

        expect(result).to eq(task)
        expect(task.reload.title).to eq('Editor Updated')
      end
    end

    context 'when user is not authorized' do
      it 'raises UnauthorizedError' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.call!(attributes: { title: 'Unauthorized Update' })
        }.to raise_error(TaskUpdateService::UnauthorizedError, "You do not have permission to edit this task")
      end

      it 'does not update the task' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.call!(attributes: { title: 'Unauthorized Update' })
        }.to raise_error(TaskUpdateService::UnauthorizedError)

        expect(task.reload.title).to eq('Original Title')
      end
    end

    context 'when validation fails' do
      it 'raises ValidationError with details' do
        service = described_class.new(task: task, user: list_owner)

        expect {
          service.call!(attributes: { title: '' })
        }.to raise_error(TaskUpdateService::ValidationError) do |error|
          expect(error.message).to eq("Validation failed")
          expect(error.details).to be_a(Hash)
          expect(error.details).to have_key(:title)
        end
      end

      it 'does not update the task on validation failure' do
        service = described_class.new(task: task, user: list_owner)

        expect {
          service.call!(attributes: { title: '' })
        }.to raise_error(TaskUpdateService::ValidationError)

        expect(task.reload.title).to eq('Original Title')
      end
    end

    context 'when updating with due_at' do
      it 'updates the due_at successfully' do
        service = described_class.new(task: task, user: list_owner)
        new_due_at = 2.hours.from_now

        service.call!(attributes: { due_at: new_due_at })

        expect(task.reload.due_at).to be_within(1.second).of(new_due_at)
      end
    end

    context 'when updating with visibility' do
      it 'updates the visibility successfully' do
        service = described_class.new(task: task, user: list_owner)

        service.call!(attributes: { visibility: 'private_task' })

        expect(task.reload.visibility).to eq('private_task')
      end
    end

    context 'when updating with strict_mode' do
      it 'updates strict_mode successfully' do
        service = described_class.new(task: task, user: list_owner)

        service.call!(attributes: { strict_mode: false })

        expect(task.reload.strict_mode).to be false
      end
    end
  end

  describe 'ValidationError' do
    it 'stores details hash' do
      error = TaskUpdateService::ValidationError.new("Test message", { field: [ "error" ] })

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({ field: [ "error" ] })
    end

    it 'handles empty details' do
      error = TaskUpdateService::ValidationError.new("Test message")

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({})
    end
  end
end
