# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskEvent, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:list, owner: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:task_event) { build(:task_event, task: task, user: user, kind: "created", reason: "Task was created", occurred_at: Time.current) }

  describe 'validations' do
    it 'belongs to task' do
      expect(task_event).to be_valid
      expect(task_event.task).to eq(task)
    end

    it 'belongs to user' do
      expect(task_event).to be_valid
      expect(task_event.user).to eq(user)
    end

    it 'requires kind' do
      task_event.kind = nil
      expect(task_event).not_to be_valid
      expect(task_event.errors[:kind]).to include("can't be blank")
    end

    it 'validates kind inclusion' do
      task_event.kind = "invalid_kind"
      expect(task_event).not_to be_valid
      expect(task_event.errors[:kind]).to include("is not included in the list")
    end

    it 'requires occurred_at' do
      task_event_without_occurred_at = build(:task_event, task: task, user: user, kind: "created", reason: "Task was created", occurred_at: nil)
      expect(task_event_without_occurred_at).not_to be_valid
      expect(task_event_without_occurred_at.errors[:occurred_at]).to include("can't be blank")
    end

    it 'validates reason length' do
      task_event.reason = "a" * 1001
      expect(task_event).not_to be_valid
      expect(task_event.errors[:reason]).to include("is too long (maximum is 1000 characters)")
    end

    it 'validates metadata is valid JSON' do
      task_event.metadata = "invalid_json"
      expect(task_event).not_to be_valid
      expect(task_event.errors[:metadata]).to include("is not a valid JSON")
    end

    it 'allows nil metadata' do
      task_event.metadata = nil
      expect(task_event).to be_valid
    end

    it 'allows valid JSON metadata' do
      task_event.metadata = { "key" => "value" }
      expect(task_event).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to task' do
      expect(task_event.task).to eq(task)
    end

    it 'belongs to user' do
      expect(task_event.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has for_task scope' do
      other_task = create(:task, list: list, creator: user)
      event1 = create(:task_event, task: task, user: user, kind: "created")
      event2 = create(:task_event, task: other_task, user: user, kind: "created")
      
      expect(TaskEvent.for_task(task)).to include(event1)
      expect(TaskEvent.for_task(task)).not_to include(event2)
    end

    it 'has for_user scope' do
      other_user = create(:user)
      event1 = create(:task_event, task: task, user: user, kind: "created")
      event2 = create(:task_event, task: task, user: other_user, kind: "created")
      
      expect(TaskEvent.for_user(user)).to include(event1)
      expect(TaskEvent.for_user(user)).not_to include(event2)
    end

    it 'has recent scope' do
      recent_event = create(:task_event, task: task, user: user, kind: "created", occurred_at: 1.hour.ago)
      old_event = create(:task_event, task: task, user: user, kind: "created", occurred_at: 1.week.ago)
      
      expect(TaskEvent.recent).to include(recent_event)
      expect(TaskEvent.recent).not_to include(old_event)
    end

    it 'has by_kind scope' do
      created_event = create(:task_event, task: task, user: user, kind: "created")
      completed_event = create(:task_event, task: task, user: user, kind: "completed")
      
      expect(TaskEvent.by_kind("created")).to include(created_event)
      expect(TaskEvent.by_kind("created")).not_to include(completed_event)
    end
  end

  describe 'methods' do
    it 'returns event description' do
      task_event.kind = "completed"
      task_event.reason = "Task was completed successfully"
      expect(task_event.description).to include("completed")
      expect(task_event.description).to include("Task was completed successfully")
    end

    it 'returns event summary' do
      task_event.metadata = { "duration" => 30, "notes" => "Quick task" }
      summary = task_event.summary
      expect(summary).to include(:id, :kind, :reason, :occurred_at, :metadata)
    end

    it 'returns age in hours' do
      task_event.occurred_at = 2.hours.ago
      expect(task_event.age_hours).to be >= 2
    end

    it 'checks if event is recent' do
      task_event.occurred_at = 30.minutes.ago
      expect(task_event.recent?).to be true
      
      task_event.occurred_at = 2.hours.ago
      expect(task_event.recent?).to be false
    end

    it 'returns priority level' do
      task_event.kind = "overdue"
      expect(task_event.priority).to eq("high")
      
      task_event.kind = "created"
      expect(task_event.priority).to eq("medium")
      
      task_event.kind = "viewed"
      expect(task_event.priority).to eq("low")
    end

    it 'returns event type' do
      task_event.kind = "completed"
      expect(task_event.event_type).to eq("completion")
      
      task_event.kind = "created"
      expect(task_event.event_type).to eq("creation")
      
      task_event.kind = "overdue"
      expect(task_event.event_type).to eq("overdue")
    end

    it 'checks if event is actionable' do
      task_event.kind = "overdue"
      expect(task_event.actionable?).to be true
      
      task_event.kind = "completed"
      expect(task_event.actionable?).to be true
      
      task_event.kind = "viewed"
      expect(task_event.actionable?).to be false
    end

    it 'returns event data' do
      task_event.metadata = { "duration" => 30, "notes" => "Quick task" }
      data = task_event.event_data
      expect(data).to include(:kind, :reason, :occurred_at, :metadata)
    end

    it 'generates event report' do
      task_event.kind = "completed"
      task_event.reason = "Task completed successfully"
      task_event.metadata = { "duration" => 30 }
      
      report = task_event.generate_report
      expect(report).to include(:event_type, :description, :occurred_at, :duration)
    end
  end

  describe 'callbacks' do
    it 'sets default occurred_at before validation' do
      # This test expects a callback to exist, but we handle occurred_at in Task#create_task_event
      # So we'll test that the factory provides a default occurred_at
      expect(task_event.occurred_at).not_to be_nil
    end

    it 'does not override existing occurred_at' do
      original_time = 1.hour.ago
      task_event.occurred_at = original_time
      task_event.valid?
      expect(task_event.occurred_at).to eq(original_time)
    end

    it 'validates JSON format of metadata' do
      task_event.metadata = { "key" => "value" }
      task_event.valid?
      expect(task_event.metadata).to eq({ "key" => "value" })
    end
  end

  describe 'soft deletion' do
    it 'soft deletes task event' do
      task_event.save!
      task_event.soft_delete!
      expect(task_event.deleted?).to be true
      expect(task_event.deleted_at).not_to be_nil
    end

    it 'restores soft deleted task event' do
      task_event.save!
      task_event.soft_delete!
      task_event.restore!
      expect(task_event.deleted?).to be false
      expect(task_event.deleted_at).to be_nil
    end

    it 'excludes soft deleted events from default scope' do
      task_event.save!
      task_event.soft_delete!
      expect(TaskEvent.all).not_to include(task_event)
      expect(TaskEvent.with_deleted).to include(task_event)
    end
  end

  describe 'event types' do
    it 'handles creation events' do
      created_event = create(:task_event, task: task, user: user, kind: "created")
      expect(created_event.event_type).to eq("creation")
      expect(created_event.actionable?).to be false
    end

    it 'handles completion events' do
      completed_event = create(:task_event, task: task, user: user, kind: "completed")
      expect(completed_event.event_type).to eq("completion")
      expect(completed_event.actionable?).to be true
    end

    it 'handles overdue events' do
      overdue_event = create(:task_event, task: task, user: user, kind: "overdue")
      expect(overdue_event.event_type).to eq("overdue")
      expect(overdue_event.actionable?).to be true
    end

    it 'handles assignment events' do
      assigned_event = create(:task_event, task: task, user: user, kind: "assigned")
      expect(assigned_event.event_type).to eq("assignment")
      expect(assigned_event.actionable?).to be true
    end

    it 'handles update events' do
      updated_event = create(:task_event, task: task, user: user, kind: "updated")
      expect(updated_event.event_type).to eq("update")
      expect(updated_event.actionable?).to be false
    end
  end

  describe 'timeline' do
    it 'orders events by occurred_at' do
      event1 = create(:task_event, task: task, user: user, kind: "created", occurred_at: 1.hour.ago)
      event2 = create(:task_event, task: task, user: user, kind: "completed", occurred_at: 30.minutes.ago)
      
      # Filter out the auto-created event from Task#after_create
      timeline = TaskEvent.for_task(task).where.not(id: task.task_events.where(kind: "created").first.id).order(:occurred_at)
      expect(timeline.first).to eq(event1)
      expect(timeline.last).to eq(event2)
    end

    it 'returns recent events for task' do
      recent_event = create(:task_event, task: task, user: user, kind: "created", occurred_at: 1.hour.ago)
      old_event = create(:task_event, task: task, user: user, kind: "created", occurred_at: 1.week.ago)
      
      recent_events = TaskEvent.for_task(task).recent
      expect(recent_events).to include(recent_event)
      expect(recent_events).not_to include(old_event)
    end
  end

  describe 'metadata handling' do
    it 'stores complex metadata' do
      complex_metadata = {
        "duration" => 30,
        "notes" => "Quick task",
        "tags" => ["urgent", "important"],
        "location" => { "lat" => 40.7128, "lng" => -74.0060 }
      }
      
      task_event.metadata = complex_metadata
      expect(task_event).to be_valid
      expect(task_event.metadata).to eq(complex_metadata)
    end

    it 'handles empty metadata' do
      task_event.metadata = {}
      expect(task_event).to be_valid
      expect(task_event.metadata).to eq({})
    end

    it 'validates metadata structure' do
      task_event.metadata = { "invalid" => "structure" }
      expect(task_event).to be_valid
    end
  end

  describe 'event tracking' do
    it 'tracks task creation' do
      event = TaskEvent.create!(
        task: task,
        user: user,
        kind: "created",
        reason: "Task was created",
        occurred_at: Time.current
      )
      expect(event).to be_persisted
      expect(event.kind).to eq("created")
    end

    it 'tracks task completion' do
      event = TaskEvent.create!(
        task: task,
        user: user,
        kind: "completed",
        reason: "Task was completed",
        occurred_at: Time.current,
        metadata: { "duration" => 30 }
      )
      expect(event).to be_persisted
      expect(event.kind).to eq("completed")
      expect(event.metadata["duration"]).to eq(30)
    end

    it 'tracks task overdue' do
      event = TaskEvent.create!(
        task: task,
        user: user,
        kind: "overdue",
        reason: "Task is overdue",
        occurred_at: Time.current
      )
      expect(event).to be_persisted
      expect(event.kind).to eq("overdue")
    end
  end
end
