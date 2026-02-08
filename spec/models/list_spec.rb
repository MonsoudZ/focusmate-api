# frozen_string_literal: true

require 'rails_helper'

RSpec.describe List, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe 'validations' do
    it 'creates list with valid attributes' do
      list = build(:list, name: "New List", description: "A new list", user: user)
      expect(list).to be_valid
      expect(list.save).to be true
    end

    it 'does not create list without name' do
      list = build(:list, name: nil, description: "A list without name", user: user)
      expect(list).not_to be_valid
      expect(list.errors[:name]).to include("can't be blank")
    end

    it 'does not create list without owner' do
      list = build(:list, name: "List without owner", description: "A list without owner", user: nil)
      expect(list).not_to be_valid
      expect(list.errors[:user]).to include("must exist")
    end

    it 'validates name length' do
      list = build(:list, name: "a" * 256, user: user)
      expect(list).not_to be_valid
      expect(list.errors[:name]).to include("is too long (maximum is 255 characters)")
    end

    it 'validates description length' do
      list = build(:list, description: "a" * 1001, user: user)
      expect(list).not_to be_valid
      expect(list.errors[:description]).to include("is too long (maximum is 1000 characters)")
    end

    it 'validates visibility inclusion' do
      list = build(:list, visibility: "invalid_visibility", user: user)
      expect(list).not_to be_valid
      expect(list.errors[:visibility]).to include("is not included in the list")
    end
  end

  describe 'associations' do
    it 'belongs to owner' do
      expect(list.user).to eq(user)
    end

    it 'has many tasks' do
      task1 = create(:task, list: list, creator: user)
      task2 = create(:task, list: list, creator: user)

      expect(list.tasks).to include(task1, task2)
      expect(list.tasks.count).to eq(2)
    end

    it 'has many memberships' do
      other_user = create(:user, email: "member@example.com")
      membership = create(:membership, list: list, user: other_user, role: "editor")

      expect(list.memberships).to include(membership)
    end

    it 'has many members through memberships' do
      other_user = create(:user, email: "member@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.members).to include(other_user)
    end
  end

  describe 'methods' do
    it 'checks if user can edit' do
      other_user = create(:user, email: "editor@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.can_edit?(user)).to be true # Owner
      expect(list.can_edit?(other_user)).to be true # Editor
    end

    it 'checks if user can view' do
      other_user = create(:user, email: "viewer@example.com")
      create(:membership, list: list, user: other_user, role: "viewer")

      expect(list.can_view?(user)).to be true # Owner
      expect(list.can_view?(other_user)).to be true # Viewer
    end







    it 'checks if list is accessible by user' do
      other_user = create(:user, email: "viewer@example.com")
      create(:membership, list: list, user: other_user, role: "viewer")

      expect(list.accessible_by?(user)).to be true # Owner
      expect(list.accessible_by?(other_user)).to be true # Viewer
    end

    it 'returns role for user' do
      other_user = create(:user, email: "editor@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.role_for(user)).to eq("owner")
      expect(list.role_for(other_user)).to eq("editor")
    end

    it 'returns nil role for non-member' do
      other_user = create(:user, email: "nonmember@example.com")
      expect(list.role_for(other_user)).to be_nil
    end

    it 'returns members' do
      other_user = create(:user, email: "member@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.members).to include(other_user)
    end

    it 'adds member to list' do
      other_user = create(:user, email: "member@example.com")
      membership = list.add_member!(other_user, "editor")

      expect(membership).to be_persisted
      expect(membership.role).to eq("editor")
      expect(list.members).to include(other_user)
    end

    it 'removes member from list' do
      other_user = create(:user, email: "member@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      list.remove_member!(other_user)
      expect(list.members).not_to include(other_user)
    end

    it 'checks if user is member' do
      other_user = create(:user, email: "member@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.member?(other_user)).to be true
    end
  end


  describe 'callbacks' do
    it 'sets default visibility before validation' do
      list = build(:list, user: user, visibility: nil)
      list.valid?
      expect(list.visibility).to eq("private")
    end

    it 'does not override existing visibility' do
      list = build(:list, user: user, visibility: "public")
      list.valid?
      expect(list.visibility).to eq("public")
    end
  end

  describe 'soft deletion' do
    it 'soft deletes list' do
      list.soft_delete!
      expect(list.deleted?).to be true
      expect(list.deleted_at).not_to be_nil
    end

    it 'restores soft deleted list' do
      list.soft_delete!
      list.restore!
      expect(list.deleted?).to be false
      expect(list.deleted_at).to be_nil
    end

    it 'excludes soft deleted lists from default scope' do
      list.soft_delete!
      expect(List.all).not_to include(list)
      expect(List.with_deleted).to include(list)
    end

    it 'soft deletes associated tasks when list is deleted' do
      task = create(:task, list: list, creator: user)
      list.soft_delete!
      task.reload
      expect(task.deleted?).to be true
    end

    it 'decrements tasks_count and parent_tasks_count on soft_delete!' do
      create(:task, list: list, creator: user)
      create(:task, list: list, creator: user)
      list.reload
      expect(list.tasks_count).to eq(2)
      expect(list.parent_tasks_count).to eq(2)

      list.soft_delete!
      list.reload
      expect(list.tasks_count).to eq(0)
      expect(list.parent_tasks_count).to eq(0)
    end

    it 'decrements subtasks_count on parent tasks on soft_delete!' do
      parent_task = create(:task, list: list, creator: user)
      create(:task, list: list, creator: user, parent_task: parent_task)
      create(:task, list: list, creator: user, parent_task: parent_task)
      parent_task.reload
      expect(parent_task.subtasks_count).to eq(2)

      list.soft_delete!
      parent_task.reload
      expect(parent_task.subtasks_count).to eq(0)
    end

    it 'handles soft_delete! on list with no tasks' do
      expect { list.soft_delete! }.not_to raise_error
      list.reload
      expect(list.tasks_count).to eq(0)
      expect(list.parent_tasks_count).to eq(0)
    end

    it 'restores cascade-deleted tasks and re-increments counters' do
      task1 = create(:task, list: list, creator: user)
      task2 = create(:task, list: list, creator: user)
      list.reload
      expect(list.tasks_count).to eq(2)

      list.soft_delete!
      list.reload
      expect(list.tasks_count).to eq(0)

      list.restore!
      list.reload
      expect(list.deleted?).to be false
      expect(list.tasks_count).to eq(2)
      expect(list.parent_tasks_count).to eq(2)
      expect(task1.reload.deleted?).to be false
      expect(task2.reload.deleted?).to be false
    end

    it 'restores subtasks_count on parent tasks after restore!' do
      parent_task = create(:task, list: list, creator: user)
      create(:task, list: list, creator: user, parent_task: parent_task)
      parent_task.reload
      expect(parent_task.subtasks_count).to eq(1)

      list.soft_delete!
      parent_task.reload
      expect(parent_task.subtasks_count).to eq(0)

      list.restore!
      parent_task.reload
      expect(parent_task.subtasks_count).to eq(1)
    end

    it 'does NOT restore individually-deleted tasks on restore!' do
      task1 = create(:task, list: list, creator: user)
      task2 = create(:task, list: list, creator: user)

      # Individually delete task1 before list deletion
      task1.soft_delete!
      list.reload

      list.soft_delete!
      list.restore!

      # task2 was cascade-deleted so it should be restored
      expect(task2.reload.deleted?).to be false
      # task1 was individually deleted before, should remain deleted
      expect(task1.reload.deleted?).to be true
    end
  end
end
