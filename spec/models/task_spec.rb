# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe 'validations' do
    it 'creates task with valid attributes' do
      task = build(:task, title: "New Task", due_at: 1.hour.from_now, list: list, creator: user, strict_mode: true)
      expect(task).to be_valid
      expect(task.save).to be true
    end

    it 'does not create task without title' do
      task = build(:task, title: nil, due_at: 1.hour.from_now, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("can't be blank")
    end

    it 'does not create task without due_at' do
      task = build(:task, title: "Test Task", due_at: nil, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:due_at]).to include("can't be blank")
    end

    it 'does not create task without list' do
      task = build(:task, title: "Test Task", due_at: 1.hour.from_now, list: nil, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:list]).to include("must exist")
    end

    it 'does not create task without creator' do
      task = build(:task, title: "Test Task", due_at: 1.hour.from_now, list: list, creator: nil)
      expect(task).not_to be_valid
      expect(task.errors[:creator]).to include("must exist")
    end

    it 'validates title length' do
      task = build(:task, title: "a" * 256, due_at: 1.hour.from_now, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("is too long (maximum is 255 characters)")
    end

    it 'validates note length' do
      task = build(:task, note: "a" * 1001, due_at: 1.hour.from_now, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:note]).to include("is too long (maximum is 1000 characters)")
    end


    it 'validates recurrence_interval for daily pattern' do
      task = build(:task,
                   recurrence_pattern: "daily",
                   recurrence_interval: 0,
                   due_at: 1.hour.from_now,
                   list: list,
                   creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_interval]).to include("must be greater than 0")
    end

    it 'allows daily pattern without recurrence_time' do
      task = build(:task,
                   recurrence_pattern: "daily",
                   recurrence_interval: 1,
                   due_at: 1.hour.from_now,
                   list: list,
                   creator: user)
      expect(task).to be_valid
    end


    it 'validates notification_interval_minutes bounds' do
      task = build(:task,
                   notification_interval_minutes: 0,
                   due_at: 1.hour.from_now,
                   list: list,
                   creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:notification_interval_minutes]).to include("must be greater than 0")
    end
  end

  describe 'associations' do
    it 'belongs to list' do
      expect(task.list).to eq(list)
    end

    it 'belongs to creator' do
      expect(task.creator).to eq(user)
    end

    it 'has many subtasks' do
      subtask = create(:task, list: list, creator: user, parent_task: task)
      expect(task.subtasks).to include(subtask)
    end

    it 'belongs to parent task' do
      parent_task = create(:task, list: list, creator: user)
      subtask = create(:task, list: list, creator: user, parent_task: parent_task)
      expect(subtask.parent_task).to eq(parent_task)
    end

    it 'has many task_events' do
      task_event = create(:task_event, task: task)
      expect(task.task_events).to include(task_event)
    end

    it 'belongs to recurring template' do
      template = create(:task, list: list, creator: user, is_recurring: true, is_template: true)
      instance = create(:task, list: list, creator: user, template: template)
      expect(instance.template).to eq(template)
    end

    it 'has many recurring instances' do
      template = create(:task, list: list, creator: user, is_recurring: true, is_template: true)
      instance = create(:task, list: list, creator: user, template: template)
      expect(template.instances).to include(instance)
    end
  end

  describe 'scopes' do
    it 'has pending scope' do
      pending_task = create(:task, list: list, creator: user, status: :pending)
      completed_task = create(:task, list: list, creator: user, status: :done)
      expect(Task.pending).to include(pending_task)
      expect(Task.pending).not_to include(completed_task)
    end

    it 'has completed scope' do
      pending_task = create(:task, list: list, creator: user, status: :pending)
      completed_task = create(:task, list: list, creator: user, status: :done)
      expect(Task.completed).to include(completed_task)
      expect(Task.completed).not_to include(pending_task)
    end

    it 'has overdue scope' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :pending)
      future_task = create(:task, list: list, creator: user, due_at: 1.hour.from_now, status: :pending)
      expect(Task.overdue).to include(overdue_task)
      expect(Task.overdue).not_to include(future_task)
    end



    it 'has recurring scope' do
      recurring_task = create(:task, list: list, creator: user, is_recurring: true)
      regular_task = create(:task, list: list, creator: user, is_recurring: false)
      expect(Task.recurring).to include(recurring_task)
      expect(Task.recurring).not_to include(regular_task)
    end
  end

  describe 'methods' do
    it 'checks if task is overdue' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :pending)
      future_task = create(:task, list: list, creator: user, due_at: 1.hour.from_now, status: :pending)
      expect(overdue_task.overdue?).to be true
      expect(future_task.overdue?).to be false
    end


    it 'checks if task is pending' do
      pending_task = create(:task, list: list, creator: user, status: :pending)
      completed_task = create(:task, list: list, creator: user, status: :done)
      expect(pending_task.pending?).to be true
      expect(completed_task.pending?).to be false
    end

    it 'checks if task is in progress' do
      in_progress_task = create(:task, list: list, creator: user, status: :in_progress)
      pending_task = create(:task, list: list, creator: user, status: :pending)
      expect(in_progress_task.in_progress?).to be true
      expect(pending_task.in_progress?).to be false
    end



    it 'checks if task is location based' do
      location_task = create(:task, list: list, creator: user, location_based: true)
      regular_task = create(:task, list: list, creator: user, location_based: false)
      expect(location_task.location_based?).to be true
      expect(regular_task.location_based?).to be false
    end





    it 'completes task' do
      task.complete!
      expect(task.status).to eq("done")
      expect(task.completed_at).not_to be_nil
    end

    it 'uncompletes task' do
      task.complete!
      task.uncomplete!
      expect(task.status).to eq("pending")
      expect(task.completed_at).to be_nil
    end

    it 'soft deletes task' do
      task.soft_delete!
      expect(task.deleted?).to be true
      expect(task.deleted_at).not_to be_nil
    end

    it 'restores soft deleted task' do
      task.soft_delete!
      task.restore!
      expect(task.deleted?).to be false
      expect(task.deleted_at).to be_nil
    end
  end

  describe 'recurring tasks' do
    it 'checks if task is overdue for recurring' do
      overdue_template = create(:task,
                               list: list,
                               creator: user,
                               is_recurring: true,
                               is_template: true,
                               due_at: 1.hour.ago)
      expect(overdue_template.overdue?).to be true
    end
  end

  describe 'location based tasks' do
    let(:location_task) do
      create(:task,
             list: list,
             creator: user,
             location_based: true,
             location_latitude: 40.7128,
             location_longitude: -74.0060,
             location_radius_meters: 100)
    end

    it 'checks arrival notification' do
      location_task.update!(notify_on_arrival: true)
      expect(location_task.notify_on_arrival?).to be true
    end

    it 'checks departure notification' do
      location_task.update!(notify_on_departure: true)
      expect(location_task.notify_on_departure?).to be true
    end
  end

  describe 'subtasks' do
    let(:parent_task) { create(:task, list: list, creator: user) }
    let(:subtask) { create(:task, list: list, creator: user, parent_task: parent_task) }

    it 'has parent task' do
      expect(subtask.parent_task).to eq(parent_task)
    end

    it 'has subtasks' do
      expect(parent_task.subtasks).to include(subtask)
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      task = build(:task, list: list, creator: user)
      task.valid?
      expect(task.status).to eq("pending")
      expect(task.visibility).to eq("private_task")
      expect(task.strict_mode).to be false
    end

    it 'updates completed_at when status changes' do
      task.complete!
      expect(task.completed_at).not_to be_nil

      task.uncomplete!
      expect(task.completed_at).to be_nil
    end
  end

  describe 'soft deletion' do
    it 'soft deletes task' do
      task.soft_delete!
      expect(task.deleted?).to be true
      expect(task.deleted_at).not_to be_nil
    end

    it 'restores soft deleted task' do
      task.soft_delete!
      task.restore!
      expect(task.deleted?).to be false
      expect(task.deleted_at).to be_nil
    end

    it 'excludes soft deleted tasks from default scope' do
      task.soft_delete!
      expect(Task.all).not_to include(task)
      expect(Task.with_deleted).to include(task)
    end

    it 'adjusts subtask counter on soft delete' do
      parent = create(:task, list: list, creator: user)
      subtask = create(:task, list: list, creator: user, parent_task: parent, due_at: nil)

      expect { subtask.soft_delete! }.to change { parent.reload.subtasks_count }.by(-1)
    end

    it 'adjusts subtask counter on restore' do
      parent = create(:task, list: list, creator: user)
      subtask = create(:task, list: list, creator: user, parent_task: parent, due_at: nil)
      subtask.soft_delete!

      expect { subtask.restore! }.to change { parent.reload.subtasks_count }.by(1)
    end

    it 'adjusts list counter for subtasks on soft delete' do
      parent = create(:task, list: list, creator: user)
      subtask = create(:task, list: list, creator: user, parent_task: parent, due_at: nil)

      expect { subtask.soft_delete! }.to change { list.reload.tasks_count }.by(-1)
      # parent_tasks_count should not change for subtasks
    end
  end

  describe '#overdue?' do
    it 'returns false when due_at is nil' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: nil)
      expect(subtask.overdue?).to be false
    end

    it 'returns false when task is done' do
      done_task = create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :done)
      expect(done_task.overdue?).to be false
    end
  end

  describe '#done?' do
    it 'returns true when status is done' do
      task.complete!
      expect(task.done?).to be true
    end

    it 'returns false when status is pending' do
      expect(task.done?).to be false
    end
  end

  describe '#editable_by?' do
    it 'returns false when user is nil' do
      expect(task.editable_by?(nil)).to be false
    end

    it 'returns true when user can edit the list' do
      expect(task.editable_by?(user)).to be true
    end
  end

  describe '#visible_to?' do
    it 'returns false when user is nil' do
      expect(task.visible_to?(nil)).to be false
    end

    it 'returns false when list is deleted' do
      list.soft_delete!
      expect(task.visible_to?(user)).to be false
    end

    it 'returns true when user has list access' do
      expect(task.visible_to?(user)).to be true
    end
  end

  describe '#subtask?' do
    it 'returns true when has parent_task_id' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: nil)
      expect(subtask.subtask?).to be true
    end

    it 'returns false when no parent_task_id' do
      expect(task.subtask?).to be false
    end
  end

  describe 'circular subtask prevention' do
    it 'prevents task from being its own parent' do
      task.parent_task_id = task.id
      expect(task).not_to be_valid
      expect(task.errors[:parent_task]).to include("cannot be self")
    end

    it 'prevents circular relationship' do
      parent = create(:task, list: list, creator: user)
      child = create(:task, list: list, creator: user, parent_task: parent, due_at: nil)

      parent.parent_task_id = child.id
      expect(parent).not_to be_valid
      expect(parent.errors[:parent_task]).to include("would create a circular relationship")
    end
  end

  describe 'recurrence validations' do
    it 'requires recurrence_days for weekly pattern' do
      task = build(:task,
                   list: list,
                   creator: user,
                   recurrence_pattern: "weekly",
                   recurrence_days: nil)
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_days]).to include("is required for weekly recurring tasks")
    end

    it 'allows weekly pattern with recurrence_days' do
      task = build(:task,
                   list: list,
                   creator: user,
                   recurrence_pattern: "weekly",
                   recurrence_days: [ 1, 3, 5 ])
      expect(task).to be_valid
    end
  end

  describe 'assigned_to validation' do
    let(:other_user) { create(:user) }

    it 'prevents assignment to user without list access' do
      task = build(:task,
                   list: list,
                   creator: user,
                   assigned_to: other_user)
      expect(task).not_to be_valid
      expect(task.errors[:assigned_to]).to include("does not have access to this list")
    end

    it 'allows assignment to user with list access' do
      create(:membership, list: list, user: other_user, role: "editor")
      task = build(:task,
                   list: list,
                   creator: user,
                   assigned_to: other_user)
      expect(task).to be_valid
    end

    it 'allows assignment to list owner' do
      task = build(:task,
                   list: list,
                   creator: user,
                   assigned_to: user)
      expect(task).to be_valid
    end
  end
end
