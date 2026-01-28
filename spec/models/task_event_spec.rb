# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskEvent do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:task_event) { create(:task_event, task: task, user: user, kind: :completed) }

  describe 'validations' do
    it 'requires kind' do
      event = build(:task_event, task: task, user: user, kind: nil)
      expect(event).not_to be_valid
    end

    it 'requires occurred_at' do
      event = build(:task_event, task: task, user: user, occurred_at: nil)
      expect(event).not_to be_valid
    end

    it 'validates reason length' do
      event = build(:task_event, task: task, user: user, reason: 'a' * 1001)
      expect(event).not_to be_valid
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
      expect(TaskEvent.for_task(task)).to include(task_event)
    end

    it 'has for_user scope' do
      expect(TaskEvent.for_user(user)).to include(task_event)
    end

    it 'has by_kind scope' do
      expect(TaskEvent.by_kind(:completed)).to include(task_event)
    end

    it 'has recent scope' do
      recent_event = create(:task_event, task: task, user: user, occurred_at: 1.hour.ago)
      old_event = create(:task_event, task: task, user: user, occurred_at: 2.days.ago)
      expect(TaskEvent.recent).to include(recent_event)
      expect(TaskEvent.recent).not_to include(old_event)
    end
  end

  describe 'soft deletion' do
    it 'soft deletes event' do
      task_event.soft_delete!
      expect(task_event.deleted?).to be true
      expect(TaskEvent.all).not_to include(task_event)
    end

    it 'includes soft deleted with scope' do
      task_event.soft_delete!
      expect(TaskEvent.with_deleted).to include(task_event)
    end
  end
end
