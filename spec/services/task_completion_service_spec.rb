require 'rails_helper'

RSpec.describe TaskCompletionService do
  let(:list_owner) { create(:user) }
  let(:task_creator) { create(:user) }
  let(:list_member) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: task_creator) }

  describe '#complete!' do
    context 'when user is the list owner' do
      it 'marks the task as complete' do
        service = described_class.new(task: task, user: list_owner)
        result = service.complete!

        expect(result).to eq(task)
        expect(task.reload.status).to eq('done')
      end
    end

    context 'when user is the task creator' do
      it 'marks the task as complete' do
        service = described_class.new(task: task, user: task_creator)
        result = service.complete!

        expect(result).to eq(task)
        expect(task.reload.status).to eq('done')
      end
    end

    context 'when user is a list member' do
      before do
        # Create a membership for the user if the association exists
        if list.respond_to?(:memberships)
          create(:membership, list: list, user: list_member, role: 'editor')
        end
      end

      it 'marks the task as complete' do
        skip 'List memberships not implemented' unless list.respond_to?(:memberships)

        service = described_class.new(task: task, user: list_member)
        result = service.complete!

        expect(result).to eq(task)
        expect(task.reload.status).to eq('done')
      end
    end

    context 'when user is not authorized' do
      it 'raises UnauthorizedError' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.complete!
        }.to raise_error(ApplicationError::Forbidden, "You do not have permission to modify this task")
      end

      it 'does not mark the task as complete' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.complete!
        }.to raise_error(ApplicationError::Forbidden)

        expect(task.reload.status).to eq('pending')
      end
    end
  end

  describe '#uncomplete!' do
    let(:completed_task) { create(:task, list: list, creator: task_creator, status: :done) }

    context 'when user is the list owner' do
      it 'marks the task as incomplete' do
        service = described_class.new(task: completed_task, user: list_owner)
        result = service.uncomplete!

        expect(result).to eq(completed_task)
        expect(completed_task.reload.status).to eq('pending')
      end
    end

    context 'when user is the task creator' do
      it 'marks the task as incomplete' do
        service = described_class.new(task: completed_task, user: task_creator)
        result = service.uncomplete!

        expect(result).to eq(completed_task)
        expect(completed_task.reload.status).to eq('pending')
      end
    end

    context 'when user is not authorized' do
      it 'raises UnauthorizedError' do
        service = described_class.new(task: completed_task, user: unauthorized_user)

        expect {
          service.uncomplete!
        }.to raise_error(ApplicationError::Forbidden, "You do not have permission to modify this task")
      end

      it 'does not mark the task as incomplete' do
        service = described_class.new(task: completed_task, user: unauthorized_user)

        expect {
          service.uncomplete!
        }.to raise_error(ApplicationError::Forbidden)

        expect(completed_task.reload.status).to eq('done')
      end
    end
  end

  describe '#toggle_completion!' do
    context 'when completed parameter is false (boolean)' do
      it 'calls uncomplete!' do
        completed_task = create(:task, list: list, creator: task_creator, status: :done)
        service = described_class.new(task: completed_task, user: list_owner)

        result = service.toggle_completion!(completed: false)

        expect(result).to eq(completed_task)
        expect(completed_task.reload.status).to eq('pending')
      end
    end

    context 'when completed parameter is "false" (string)' do
      it 'calls uncomplete!' do
        completed_task = create(:task, list: list, creator: task_creator, status: :done)
        service = described_class.new(task: completed_task, user: list_owner)

        result = service.toggle_completion!(completed: "false")

        expect(result).to eq(completed_task)
        expect(completed_task.reload.status).to eq('pending')
      end
    end

    context 'when completed parameter is true' do
      it 'calls complete!' do
        service = described_class.new(task: task, user: list_owner)

        result = service.toggle_completion!(completed: true)

        expect(result).to eq(task)
        expect(task.reload.status).to eq('done')
      end
    end

    context 'when completed parameter is any other value' do
      it 'calls complete!' do
        service = described_class.new(task: task, user: list_owner)

        result = service.toggle_completion!(completed: "yes")

        expect(result).to eq(task)
        expect(task.reload.status).to eq('done')
      end
    end

    context 'when user is not authorized' do
      it 'raises UnauthorizedError' do
        service = described_class.new(task: task, user: unauthorized_user)

        expect {
          service.toggle_completion!(completed: true)
        }.to raise_error(ApplicationError::Forbidden)
      end
    end
  end
end
