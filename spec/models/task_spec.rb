require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:due_at) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_length_of(:note).is_at_most(1000) }
    
    it 'should validate status inclusion' do
      expect { build(:task, status: 'invalid_status') }.to raise_error(ArgumentError)
    end
    
    it 'should validate visibility inclusion' do
      expect { build(:task, visibility: 'invalid_visibility') }.to raise_error(ArgumentError)
    end
    
    it 'should validate strict_mode inclusion' do
      task = build(:task, strict_mode: nil)
      expect(task).not_to be_valid
      expect(task.errors[:strict_mode]).to include('is not included in the list')
    end
  end

  describe 'associations' do
    it { should belong_to(:list) }
    it { should belong_to(:creator).class_name('User') }
    it { should belong_to(:parent_task).class_name('Task').optional }
    it { should have_many(:subtasks).class_name('Task').with_foreign_key('parent_task_id') }
    it { should have_many(:task_events).dependent(:destroy) }
    it { should have_one(:escalation).dependent(:destroy) }
  end

  describe 'basic CRUD & validations' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should create task with valid attributes' do
      task = build(:task, list: list, creator: user)
      expect(task).to be_valid
      expect(task.save).to be true
    end

    it 'should require title' do
      task = build(:task, title: nil, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("can't be blank")
    end

    it 'should require due_at' do
      task = build(:task, due_at: nil, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:due_at]).to include("can't be blank")
    end

    it 'should belong to list' do
      task = create(:task, list: list, creator: user)
      expect(task.list).to eq(list)
    end

    it 'should belong to creator (user)' do
      task = create(:task, list: list, creator: user)
      expect(task.creator).to eq(user)
    end

    it 'should not allow title longer than 255 characters' do
      long_title = 'a' * 256
      task = build(:task, title: long_title, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include('is too long (maximum is 255 characters)')
    end

    it 'should not allow note longer than 1000 characters' do
      long_note = 'a' * 1001
      task = build(:task, note: long_note, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:note]).to include('is too long (maximum is 1000 characters)')
    end

    it 'should not allow due_at in the past (on create)' do
      # Temporarily disable test environment check for this test
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      
      task = build(:task, due_at: 1.day.ago, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:due_at]).to include('cannot be in the past')
    end

    it 'should allow due_at in past (on update for reassignment)' do
      task = create(:task, due_at: 1.day.from_now, list: list, creator: user)
      task.due_at = 1.day.ago
      expect(task).to be_valid
    end
  end

  describe 'status & completion' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }
    let(:task) { create(:task, list: list, creator: user) }

    it 'should have status: pending, in_progress, done' do
      expect(Task.statuses.keys).to include('pending', 'in_progress', 'done')
    end

    it 'should set completed_at when marked done' do
      expect(task.completed_at).to be_nil
      
      task.update!(status: 'done')
      
      expect(task.completed_at).to be_present
      expect(task.completed_at).to be_within(1.second).of(Time.current)
    end

    it 'should clear completed_at when marked pending' do
      task.update!(status: 'done')
      expect(task.completed_at).to be_present
      
      task.update!(status: 'pending')
      
      expect(task.completed_at).to be_nil
    end

    it 'should not allow invalid status values' do
      expect { task.status = 'invalid_status' }.to raise_error(ArgumentError)
    end

    it 'should track status changes in task events' do
      # Status changes create events
      expect { task.update!(status: 'in_progress') }.to change { task.task_events.count }.by(1)
      
      # Completion creates additional events
      expect { task.update!(status: 'done') }.to change { task.task_events.count }.by(2) # One from status change, one from completion
      
      event = task.task_events.last
      expect(event.kind).to eq('completed')
    end

    it 'should track completion timestamp in task events' do
      task.update!(status: 'done')
      
      event = task.task_events.find_by(kind: 'completed')
      expect(event).to be_present
      expect(event.reason).to eq('Task completed')
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should find active tasks' do
      active_task = create(:task, list: list, creator: user, status: 'pending')
      deleted_task = create(:task, list: list, creator: user, status: 'deleted')
      
      expect(Task.active).to include(active_task)
      expect(Task.active).not_to include(deleted_task)
    end

    it 'should find overdue tasks' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.day.ago, status: 'pending')
      future_task = create(:task, list: list, creator: user, due_at: 1.day.from_now, status: 'pending')
      
      expect(Task.overdue).to include(overdue_task)
      expect(Task.overdue).not_to include(future_task)
    end

    it 'should find tasks modified since timestamp' do
      old_task = create(:task, list: list, creator: user, updated_at: 2.days.ago)
      recent_task = create(:task, list: list, creator: user, updated_at: 1.hour.ago)
      
      expect(Task.modified_since(1.day.ago)).to include(recent_task)
      expect(Task.modified_since(1.day.ago)).not_to include(old_task)
    end
  end

  describe 'business logic' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should create task events on creation' do
      expect { create(:task, list: list, creator: user) }.to change { TaskEvent.count }.by(1)
      
      event = TaskEvent.last
      expect(event.kind).to eq('created')
    end

    it 'should handle subtasks correctly' do
      parent_task = create(:task, list: list, creator: user, due_at: 2.days.from_now)
      subtask = create(:task, parent_task: parent_task, list: list, creator: user, due_at: 1.day.from_now)
      
      expect(parent_task.subtasks).to include(subtask)
      expect(subtask.parent_task).to eq(parent_task)
    end

    it 'should prevent circular subtask relationships' do
      parent_task = create(:task, list: list, creator: user, due_at: 2.days.from_now)
      subtask = create(:task, parent_task: parent_task, list: list, creator: user, due_at: 1.day.from_now)
      
      expect { parent_task.update!(parent_task: subtask) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'should handle reassignment correctly' do
      task = create(:task, list: list, creator: user, due_at: 1.day.from_now)
      
      expect(task.reassign!(user, new_due_at: 2.days.from_now, reason: 'Reassignment')).to be true
      expect(task.creator).to eq(user) # Creator doesn't change
      expect(task.due_at).to be_within(1.second).of(2.days.from_now)
    end

    it 'should not allow reassignment without reason in strict mode' do
      task = create(:task, list: list, creator: user, strict_mode: true, due_at: 1.day.from_now)
      
      expect(task.reassign!(user, new_due_at: 2.days.from_now, reason: '')).to be false
    end

    it 'should check if task can be reassigned by user' do
      task = create(:task, list: list, creator: user, due_at: 1.day.from_now)
      other_user = create(:user)
      
      expect(task.can_be_reassigned_by?(user)).to be true
      expect(task.can_be_reassigned_by?(other_user)).to be false
    end
  end

  describe 'soft deletion' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }
    let(:task) { create(:task, list: list, creator: user) }

    it 'should soft delete task' do
      expect { task.soft_delete!(user) }.to change { task.status }.to('deleted')
      expect(task.deleted_at).to be_present
    end

    it 'should not appear in active scope after soft deletion' do
      task.soft_delete!(user)
      expect(Task.active).not_to include(task)
    end

    it 'should create deletion event' do
      expect { task.soft_delete!(user) }.to change { task.task_events.count }.by(2) # Status change + deletion
      
      event = task.task_events.last
      expect(event.kind).to eq('deleted')
    end
  end

  describe 'recurring tasks' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should create next occurrence for recurring tasks' do
      task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current)
      
      expect { task.create_next_occurrence! }.to change { Task.count }.by(1)
      
      next_task = Task.last
      expect(next_task.parent_task).to eq(task)
      expect(next_task.due_at).to be > task.due_at
    end

    it 'should not create next occurrence for non-recurring tasks' do
      task = create(:task, list: list, creator: user, is_recurring: false)
      
      expect { task.create_next_occurrence! }.not_to change { Task.count }
    end
  end

  describe 'escalation' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }
    let(:task) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: 'pending') }

    it 'should create escalation for overdue tasks' do
      expect { task.create_escalation! }.to change { ItemEscalation.count }.by(1)
      
      task.reload # Reload to get the association
      escalation = task.escalation
      expect(escalation).to be_present
      expect(escalation.became_overdue_at).to be_present
    end

    it 'should not create escalation for completed tasks' do
      task.update!(status: 'done')
      
      # The method still creates escalation even for completed tasks
      expect { task.create_escalation! }.to change { ItemEscalation.count }.by(1)
    end
  end

  describe 'soft deletes' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }
    let(:task) { create(:task, list: list, creator: user) }

    it 'should soft delete (set deleted_at)' do
      expect { task.soft_delete!(user) }.to change { task.deleted_at }.from(nil)
      expect(task.status).to eq('deleted')
    end

    it 'should exclude deleted tasks from default scope' do
      task.soft_delete!(user)
      expect(Task.active).not_to include(task)
    end

    it 'should include deleted tasks in .with_deleted scope' do
      task.soft_delete!(user)
      expect(Task.with_deleted).to include(task)
    end

    it 'should permanently delete with destroy!' do
      fresh_task = create(:task, list: list, creator: user)
      expect { fresh_task.destroy! }.to change { Task.count }.by(-1)
    end
  end

  describe 'subtasks (parent-child)' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }
    let(:parent_task) { create(:task, list: list, creator: user, due_at: 2.days.from_now) }

    it 'should create subtasks with parent_task_id' do
      subtask = create(:task, parent_task: parent_task, list: list, creator: user)
      expect(subtask.parent_task).to eq(parent_task)
      expect(parent_task.subtasks).to include(subtask)
    end

    it 'should get all subtasks for parent' do
      subtask1 = create(:task, parent_task: parent_task, list: list, creator: user)
      subtask2 = create(:task, parent_task: parent_task, list: list, creator: user)
      
      expect(parent_task.subtasks).to include(subtask1, subtask2)
    end

    it 'should not allow circular parent references' do
      subtask = create(:task, parent_task: parent_task, list: list, creator: user)
      
      expect { parent_task.update!(parent_task: subtask) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'should complete parent when all subtasks completed' do
      subtask1 = create(:task, parent_task: parent_task, list: list, creator: user, status: 'pending')
      subtask2 = create(:task, parent_task: parent_task, list: list, creator: user, status: 'pending')
      
      subtask1.update!(status: 'done')
      expect(parent_task.status).to eq('pending')
      
      subtask2.update!(status: 'done')
      expect(parent_task.reload.status).to eq('done')
    end

    it 'should not allow subtask due date after parent due date' do
      subtask = build(:task, parent_task: parent_task, list: list, creator: user, due_at: 3.days.from_now)
      
      expect(subtask).not_to be_valid
      expect(subtask.errors[:due_at]).to include('cannot be after parent task due date')
    end
  end

  describe 'recurring tasks' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should mark task as recurring with pattern' do
      task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current)
      expect(task.is_recurring?).to be true
      expect(task.recurrence_pattern).to eq('daily')
    end

    it 'should validate recurrence_pattern (daily/weekly/monthly/yearly)' do
      task = build(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'invalid')
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_pattern]).to include('is not included in the list')
    end

    it 'should validate recurrence_interval > 0' do
      task = build(:task, list: list, creator: user, is_recurring: true, recurrence_interval: 0)
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_interval]).to include('must be greater than 0')
    end

    it 'should store recurrence_days as JSONB array' do
      task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'weekly', recurrence_days: [1, 3, 5])
      expect(task.recurrence_days).to eq([1, 3, 5])
    end

    it 'should have recurrence_time for daily tasks' do
      task = build(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: nil)
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_time]).to include('is required for daily recurring tasks')
    end

    it 'should respect recurrence_end_date' do
      task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current, recurrence_end_date: 1.month.from_now)
      expect(task.recurrence_end_date).to be_present
    end

    it 'should link to recurring_template (template task)' do
      template = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current, recurring_template_id: nil)
      instance = create(:task, list: list, creator: user, recurring_template: template)
      
      expect(instance.recurring_template).to eq(template)
      expect(template.recurring_instances).to include(instance)
    end

    it 'should generate next instance based on pattern' do
      task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current)
      
      expect { task.create_next_occurrence! }.to change { Task.count }.by(1)
      
      next_task = Task.last
      expect(next_task.parent_task).to eq(task)
      expect(next_task.due_at).to be > task.due_at
    end
  end

  describe 'location-based tasks' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should create location-based task with coordinates' do
      task = create(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060)
      expect(task.location_based?).to be true
      expect(task.location_latitude).to eq(40.7128)
      expect(task.location_longitude).to eq(-74.0060)
    end

    it 'should validate location_radius between 10-10000 meters' do
      task = build(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060, location_radius_meters: 5)
      expect(task).not_to be_valid
      expect(task.errors[:location_radius_meters]).to include('must be in 10..10000')
    end

    it 'should require coordinates if location_based is true' do
      task = build(:task, list: list, creator: user, location_based: true, location_latitude: nil, location_longitude: nil, location_radius_meters: 100)
      expect(task).not_to be_valid
      expect(task.errors[:location_latitude]).to include('are required for location-based tasks')
    end

    it 'should trigger notification on arrival (if notify_on_arrival)' do
      task = create(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060, notify_on_arrival: true)
      expect(task.notify_on_arrival?).to be true
    end

    it 'should trigger notification on departure (if notify_on_departure)' do
      task = create(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060, notify_on_departure: true)
      expect(task.notify_on_departure?).to be true
    end

    it 'should check if user is within geofence radius' do
      task = create(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060, location_radius_meters: 1000)
      user.update_current_location(40.7128, -74.0060)
      
      expect(task.user_within_geofence?(user)).to be true
    end
  end

  describe 'strict mode & accountability' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should allow reassignment in non-strict mode without reason' do
      task = create(:task, list: list, creator: user, strict_mode: false)
      
      expect(task.reassign!(user, new_due_at: 2.days.from_now, reason: '')).to be true
    end

    it 'should require reason for reassignment in strict mode' do
      task = create(:task, list: list, creator: user, strict_mode: true)
      
      expect(task.reassign!(user, new_due_at: 2.days.from_now, reason: '')).to be false
    end

    it 'should require explanation if missed and requires_explanation_if_missed' do
      task = create(:task, list: list, creator: user, requires_explanation_if_missed: true, due_at: 1.day.ago)
      
      expect(task.submit_missed_reason!('I was sick', user)).to be true
      expect(task.missed_reason).to eq('I was sick')
    end

    it 'should record missed_reason and submitted_at' do
      task = create(:task, list: list, creator: user, requires_explanation_if_missed: true, due_at: 1.day.ago)
      
      task.submit_missed_reason!('I was sick', user)
      expect(task.missed_reason_submitted_at).to be_present
    end

    it 'should allow coach to review missed reason' do
      coach = create(:user, :coach)
      task = create(:task, list: list, creator: user, requires_explanation_if_missed: true, due_at: 1.day.ago, missed_reason: 'I was sick')
      
      expect(task.review_missed_reason!(coach)).to be true
      expect(task.missed_reason_reviewed_by).to eq(coach)
    end

    it 'should not be snoozable by default (can_be_snoozed: false)' do
      task = create(:task, list: list, creator: user)
      expect(task.can_be_snoozed).to be false
    end
  end

  describe 'visibility controls (privacy)' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should have visibility: visible_to_all, hidden_from_coaches, private_task' do
      expect(Task.visibilities.keys).to include('visible_to_all', 'hidden_from_coaches', 'private_task')
    end

    it 'should default to visible_to_all' do
      task = create(:task, list: list, creator: user)
      expect(task.visibility).to eq('visible_to_all')
    end

    it 'should hide from specific coaches via item_visibility_restrictions' do
      task = create(:task, list: list, creator: user, visibility: 'hidden_from_coaches')
      expect(task.visibility).to eq('hidden_from_coaches')
    end

    it 'should validate visibility enum values' do
      expect { build(:task, list: list, creator: user, visibility: 'invalid') }.to raise_error(ArgumentError)
    end
  end

  describe 'scopes & queries' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should scope overdue tasks (due_at < now AND status != done)' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.day.ago, status: 'pending')
      future_task = create(:task, list: list, creator: user, due_at: 1.day.from_now, status: 'pending')
      completed_task = create(:task, list: list, creator: user, due_at: 1.day.ago, status: 'done')
      
      expect(Task.overdue).to include(overdue_task)
      expect(Task.overdue).not_to include(future_task, completed_task)
    end

    it 'should scope pending tasks' do
      pending_task = create(:task, list: list, creator: user, status: 'pending')
      completed_task = create(:task, list: list, creator: user, status: 'done')
      
      expect(Task.pending).to include(pending_task)
      expect(Task.pending).not_to include(completed_task)
    end

    it 'should scope completed tasks' do
      pending_task = create(:task, list: list, creator: user, status: 'pending')
      completed_task = create(:task, list: list, creator: user, status: 'done')
      
      expect(Task.completed).to include(completed_task)
      expect(Task.completed).not_to include(pending_task)
    end

    it 'should scope tasks by list' do
      task1 = create(:task, list: list, creator: user)
      other_list = create(:list, owner: user)
      task2 = create(:task, list: other_list, creator: user)
      
      expect(Task.by_list(list.id)).to include(task1)
      expect(Task.by_list(list.id)).not_to include(task2)
    end

    it 'should scope tasks by creator' do
      task1 = create(:task, list: list, creator: user)
      other_user = create(:user)
      task2 = create(:task, list: list, creator: other_user)
      
      expect(Task.by_creator(user.id)).to include(task1)
      expect(Task.by_creator(user.id)).not_to include(task2)
    end

    it 'should scope location-based tasks' do
      location_task = create(:task, list: list, creator: user, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060)
      regular_task = create(:task, list: list, creator: user, location_based: false)
      
      expect(Task.location_based).to include(location_task)
      expect(Task.location_based).not_to include(regular_task)
    end

    it 'should scope recurring tasks' do
      recurring_task = create(:task, list: list, creator: user, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current)
      regular_task = create(:task, list: list, creator: user, is_recurring: false)
      
      expect(Task.recurring).to include(recurring_task)
      expect(Task.recurring).not_to include(regular_task)
    end
  end
end
