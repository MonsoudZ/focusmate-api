require 'rails_helper'

RSpec.describe TaskEventRecorder do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:recorder) { described_class.new(task) }

  describe '#record_creation' do
    it 'creates a task event' do
      # Clear any existing events from task creation
      task.task_events.destroy_all

      expect {
        recorder.record_creation(kind: 'created', reason: 'test reason')
      }.to change(TaskEvent, :count).by(1)

      event = TaskEvent.last
      expect(event.task).to eq(task)
      expect(event.kind).to eq('created')
      expect(event.reason).to eq('test reason')
    end

    it 'uses provided user or defaults to task creator' do
      other_user = create(:user)
      recorder.record_creation(kind: 'updated', user: other_user)

      event = TaskEvent.last
      expect(event.user).to eq(other_user)
    end
  end

  describe '#record_status_change' do
    it 'records completion event when task is done' do
      task.update!(status: :done)
      recorder.record_status_change

      event = TaskEvent.last
      expect(event.kind).to eq('completed')
    end

    it 'records creation event when task is pending' do
      task.update!(status: :pending)
      recorder.record_status_change

      event = TaskEvent.last
      expect(event.kind).to eq('created')
    end
  end

  describe '#check_parent_completion' do
    let(:parent_task) { create(:task, list: list, creator: user) }
    let(:subtask) { create(:task, list: list, creator: user, parent_task: parent_task) }

    it 'completes parent when all subtasks are done' do
      subtask.update!(status: :done)
      recorder.check_parent_completion

      expect(parent_task.reload.status).to eq('done')
    end

    it 'does not complete parent when subtasks remain pending' do
      subtask.update!(status: :pending)
      recorder.check_parent_completion

      expect(parent_task.reload.status).to eq('pending')
    end
  end
end
