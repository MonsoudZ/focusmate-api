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

    it 'validates status inclusion' do
      task = build(:task, status: "invalid_status", due_at: 1.hour.from_now, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:status]).to include("is not included in the list")
    end

    it 'validates visibility inclusion' do
      task = build(:task, visibility: "invalid_visibility", due_at: 1.hour.from_now, list: list, creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:visibility]).to include("is not included in the list")
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

    it 'validates recurrence_time for daily pattern' do
      task = build(:task,
                   recurrence_pattern: "daily",
                   recurrence_time: nil,
                   due_at: 1.hour.from_now,
                   list: list,
                   creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:recurrence_time]).to include("is required for daily recurring tasks")
    end

    it 'validates location_radius_meters bounds' do
      task = build(:task,
                   location_radius_meters: 0,
                   due_at: 1.hour.from_now,
                   list: list,
                   creator: user)
      expect(task).not_to be_valid
      expect(task.errors[:location_radius_meters]).to include("must be greater than 0")
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
      instance = create(:task, list: list, creator: user, recurring_template: template)
      expect(instance.recurring_template).to eq(template)
    end

    it 'has many recurring instances' do
      template = create(:task, list: list, creator: user, is_recurring: true, is_template: true)
      instance = create(:task, list: list, creator: user, recurring_template: template)
      expect(template.recurring_instances).to include(instance)
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

    it 'has location_based scope' do
      location_task = create(:task, list: list, creator: user, location_based: true)
      regular_task = create(:task, list: list, creator: user, location_based: false)
      expect(Task.location_based).to include(location_task)
      expect(Task.location_based).not_to include(regular_task)
    end

    it 'has recurring scope' do
      recurring_task = create(:task, list: list, creator: user, is_recurring: true)
      regular_task = create(:task, list: list, creator: user, is_recurring: false)
      expect(Task.recurring).to include(recurring_task)
      expect(Task.recurring).not_to include(regular_task)
    end

    it 'has templates scope' do
      template = create(:task, list: list, creator: user, is_template: true)
      instance = create(:task, list: list, creator: user, is_template: false)
      expect(Task.templates).to include(template)
      expect(Task.templates).not_to include(instance)
    end

    it 'has instances scope' do
      template = create(:task, list: list, creator: user, is_template: true)
      instance = create(:task, list: list, creator: user, is_template: false)
      expect(Task.instances).to include(instance)
      expect(Task.instances).not_to include(template)
    end
  end

  describe 'methods' do
    it 'checks if task is overdue' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :pending)
      future_task = create(:task, list: list, creator: user, due_at: 1.hour.from_now, status: :pending)
      expect(overdue_task.overdue?).to be true
      expect(future_task.overdue?).to be false
    end

    it 'checks if task is completed' do
      completed_task = create(:task, list: list, creator: user, status: :done)
      pending_task = create(:task, list: list, creator: user, status: :pending)
      expect(completed_task.completed?).to be true
      expect(pending_task.completed?).to be false
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

    it 'checks if task is recurring' do
      recurring_task = create(:task, list: list, creator: user, is_recurring: true)
      regular_task = create(:task, list: list, creator: user, is_recurring: false)
      expect(recurring_task.recurring?).to be true
      expect(regular_task.recurring?).to be false
    end

    it 'checks if task is template' do
      template = create(:task, list: list, creator: user, is_template: true)
      instance = create(:task, list: list, creator: user, is_template: false)
      expect(template.template?).to be true
      expect(instance.template?).to be false
    end

    it 'checks if task is instance' do
      template = create(:task, list: list, creator: user, is_template: true)
      instance = create(:task, list: list, creator: user, is_template: false)
      expect(instance.instance?).to be true
      expect(template.instance?).to be false
    end

    it 'checks if task is location based' do
      location_task = create(:task, list: list, creator: user, location_based: true)
      regular_task = create(:task, list: list, creator: user, location_based: false)
      expect(location_task.location_based?).to be true
      expect(regular_task.location_based?).to be false
    end

    it 'checks if task can be snoozed' do
      snoozable_task = create(:task, list: list, creator: user, can_be_snoozed: true)
      non_snoozable_task = create(:task, list: list, creator: user, can_be_snoozed: false)
      expect(snoozable_task.snoozable?).to be true
      expect(non_snoozable_task.snoozable?).to be false
    end

    it 'checks if task requires explanation' do
      explanation_task = create(:task, list: list, creator: user, requires_explanation_if_missed: true)
      regular_task = create(:task, list: list, creator: user, requires_explanation_if_missed: false)
      expect(explanation_task.requires_explanation?).to be true
      expect(regular_task.requires_explanation?).to be false
    end

    it 'checks if task was created by coach' do
      coach = create(:user, role: "coach")
      coach_task = create(:task, list: list, creator: coach)
      client_task = create(:task, list: list, creator: user)
      expect(coach_task.created_by_coach?).to be true
      expect(client_task.created_by_coach?).to be false
    end

    it 'checks if task is visible to user' do
      other_user = create(:user)
      visible_task = create(:task, list: list, creator: user, visibility: :visible_to_all)
      private_task = create(:task, list: list, creator: user, visibility: :private_task)

      expect(visible_task.visible_to?(user)).to be true
      expect(visible_task.visible_to?(other_user)).to be true
      expect(private_task.visible_to?(user)).to be true
      expect(private_task.visible_to?(other_user)).to be false
    end

    it 'checks if user is within geofence' do
      location_task = create(:task,
                             list: list,
                             creator: user,
                             location_based: true,
                             location_latitude: 40.7128,
                             location_longitude: -74.0060,
                             location_radius_meters: 100)

      user.update!(latitude: 40.7128, longitude: -74.0060)
      expect(location_task.user_within_geofence?(user)).to be true

      user.update!(latitude: 40.8000, longitude: -74.0000)
      expect(location_task.user_within_geofence?(user)).to be false
    end

    it 'calculates age in hours' do
      old_task = create(:task, list: list, creator: user, created_at: 2.hours.ago)
      new_task = create(:task, list: list, creator: user, created_at: 30.minutes.ago)

      expect(old_task.age_hours).to be >= 2
      expect(new_task.age_hours).to be < 1
    end

    it 'checks if task is recent' do
      recent_task = create(:task, list: list, creator: user, created_at: 30.minutes.ago)
      old_task = create(:task, list: list, creator: user, created_at: 2.hours.ago)

      expect(recent_task.recent?).to be true
      expect(old_task.recent?).to be false
    end

    it 'returns priority level' do
      urgent_task = create(:task, list: list, creator: user, due_at: 1.hour.from_now)
      normal_task = create(:task, list: list, creator: user, due_at: 1.day.from_now)

      expect(urgent_task.priority).to eq("high")
      expect(normal_task.priority).to eq("medium")
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

    it 'snoozes task' do
      task.snooze!(1.hour)
      expect(task.due_at).to be > 1.hour.from_now
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
    let(:template) { create(:task, list: list, creator: user, is_recurring: true, is_template: true, recurrence_pattern: "daily", recurrence_time: "09:00") }

    it 'generates next instance' do
      instance = template.generate_next_instance
      expect(instance).to be_a(Task)
      expect(instance.recurring_template).to eq(template)
      expect(instance.is_template).to be false
    end

    it 'calculates next due date' do
      next_due = template.calculate_next_due_date
      expect(next_due).to be > Time.current
    end

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

    it 'calculates distance to user' do
      user.update!(latitude: 40.7128, longitude: -74.0060)
      distance = location_task.distance_to_user(user)
      expect(distance).to be < 1 # Should be very close
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

    it 'completes parent when all subtasks are done' do
      subtask.complete!
      parent_task.check_completion
      expect(parent_task.status).to eq("done")
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
  end
end
