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

  describe 'overdue task with required explanation' do
    let(:overdue_task) do
      create(:task,
             list: list,
             creator: task_creator,
             due_at: 1.hour.ago,
             requires_explanation_if_missed: true)
    end

    context 'when reason is not provided' do
      it 'raises MissingReasonError' do
        service = described_class.new(task: overdue_task, user: list_owner)

        expect {
          service.complete!
        }.to raise_error(ApplicationError::UnprocessableEntity, "This overdue task requires an explanation")
      end
    end

    context 'when reason is provided' do
      it 'completes the task with reason' do
        service = described_class.new(task: overdue_task, user: list_owner, missed_reason: "Was in a meeting")
        result = service.complete!

        expect(result.status).to eq('done')
        expect(result.missed_reason).to eq("Was in a meeting")
        expect(result.missed_reason_submitted_at).to be_present
      end
    end

    context 'when task is not overdue' do
      let(:future_task) do
        create(:task,
               list: list,
               creator: task_creator,
               due_at: 1.hour.from_now,
               requires_explanation_if_missed: true)
      end

      it 'completes without requiring reason' do
        service = described_class.new(task: future_task, user: list_owner)
        result = service.complete!

        expect(result.status).to eq('done')
      end
    end

    context 'when task has no due_at' do
      let(:no_due_task) do
        parent = create(:task, list: list, creator: task_creator)
        create(:task,
               list: list,
               creator: task_creator,
               parent_task: parent,
               due_at: nil,
               requires_explanation_if_missed: true)
      end

      it 'completes without requiring reason' do
        service = described_class.new(task: no_due_task, user: list_owner)
        result = service.complete!

        expect(result.status).to eq('done')
      end
    end
  end

  describe 'class methods' do
    it '.complete! completes the task' do
      result = described_class.complete!(task: task, user: list_owner)

      expect(result.status).to eq('done')
    end

    it '.uncomplete! uncompletes the task' do
      task.complete!
      result = described_class.uncomplete!(task: task, user: list_owner)

      expect(result.status).to eq('pending')
    end

    it '.toggle! toggles the task status' do
      result = described_class.toggle!(task: task, user: list_owner, completed: true)

      expect(result.status).to eq('done')
    end
  end

  describe 'analytics tracking' do
    it 'tracks task completion' do
      expect(AnalyticsTracker).to receive(:task_completed).with(
        task,
        list_owner,
        hash_including(:was_overdue, :minutes_overdue)
      )

      described_class.complete!(task: task, user: list_owner)
    end

    it 'tracks task reopening' do
      task.complete!
      expect(AnalyticsTracker).to receive(:task_reopened).with(task, list_owner)

      described_class.uncomplete!(task: task, user: list_owner)
    end
  end

  describe 'recurring task generation' do
    let(:template) { create(:task, list: list, creator: task_creator, is_template: true, template_type: "recurring", is_recurring: true, recurrence_pattern: "daily") }
    let(:recurring_instance) { create(:task, list: list, creator: task_creator, template: template, instance_number: 1) }

    it 'enqueues job to generate next instance for recurring tasks' do
      expect {
        described_class.complete!(task: recurring_instance, user: list_owner)
      }.to have_enqueued_job(RecurringTaskInstanceJob).with(user_id: list_owner.id, task_id: recurring_instance.id)
    end

    it 'does not enqueue job for tasks without template_id' do
      non_recurring_task = create(:task, list: list, creator: task_creator)

      expect {
        described_class.complete!(task: non_recurring_task, user: list_owner)
      }.not_to have_enqueued_job(RecurringTaskInstanceJob)
    end

    it 'does not enqueue job for tasks with non-recurring template' do
      non_recurring_template = create(:task, list: list, creator: task_creator, is_template: true, template_type: "checklist")
      task_with_template = create(:task, list: list, creator: task_creator)
      task_with_template.update_column(:template_id, non_recurring_template.id)

      expect {
        described_class.complete!(task: task_with_template.reload, user: list_owner)
      }.not_to have_enqueued_job(RecurringTaskInstanceJob)
    end
  end

  describe 'streak update' do
    it 'enqueues streak update job' do
      expect {
        described_class.complete!(task: task, user: list_owner)
      }.to have_enqueued_job(StreakUpdateJob).with(user_id: list_owner.id)
    end
  end

  describe 'access control via membership' do
    it 'allows completion by list member' do
      # Create membership for a user who is not list owner or task creator
      create(:membership, list: list, user: list_member, role: 'editor')

      service = described_class.new(task: task, user: list_member)
      result = service.complete!

      expect(result.status).to eq('done')
    end
  end
end
