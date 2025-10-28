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

    it 'has many list_shares' do
      other_user = create(:user, email: "shared@example.com")
      list_share = create(:list_share, list: list, user: other_user)

      expect(list.list_shares).to include(list_share)
    end

    it 'has many shared_users through list_shares' do
      other_user = create(:user, email: "shared@example.com")
      create(:list_share, list: list, user: other_user)

      expect(list.shared_users).to include(other_user)
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

    it 'checks if user can add items' do
      other_user = create(:user, email: "editor@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.can_add_items_by?(user)).to be true # Owner
      expect(list.can_add_items_by?(other_user)).to be true # Editor
    end

    it 'checks if user can delete items' do
      other_user = create(:user, email: "editor@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.can_delete_items_by?(user)).to be true # Owner
      expect(list.can_delete_items_by?(other_user)).to be true # Editor
    end

    it 'checks if list is editable by user' do
      other_user = create(:user, email: "editor@example.com")
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.editable_by?(user)).to be true # Owner
      expect(list.editable_by?(other_user)).to be true # Editor
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

    it 'checks if user is coach' do
      coach = create(:user, role: "coach")
      client = create(:user, role: "client")
      create(:coaching_relationship, coach: coach, client: client, status: :active)
      create(:membership, list: list, user: coach, role: "editor")

      expect(list.coach?(coach)).to be true
      expect(list.coach?(client)).to be false
    end

    it 'shares list with user' do
      other_user = create(:user, email: "shared@example.com")
      list.share_with!(other_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false
      })

      list_share = list.list_shares.find_by(user: other_user)
      expect(list_share).to be_present
      expect(list_share.can_view).to be true
      expect(list_share.can_edit).to be true
      expect(list_share.can_add_items).to be true
      expect(list_share.can_delete_items).to be false
    end

    it 'unshares list with user' do
      other_user = create(:user, email: "shared@example.com")
      create(:list_share, list: list, user: other_user)

      list.unshare_with!(other_user)
      expect(list.list_shares.find_by(user: other_user)).to be_nil
    end

    it 'checks if list is shared with user' do
      other_user = create(:user, email: "shared@example.com")
      create(:list_share, list: list, user: other_user)

      expect(list.shared_with?(other_user)).to be true
    end

    it 'returns shared users' do
      other_user1 = create(:user, email: "shared1@example.com")
      other_user2 = create(:user, email: "shared2@example.com")
      create(:list_share, list: list, user: other_user1)
      create(:list_share, list: list, user: other_user2)

      expect(list.shared_users).to include(other_user1, other_user2)
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

    it 'returns task count' do
      create(:task, list: list, creator: user)
      create(:task, list: list, creator: user)

      expect(list.task_count).to eq(2)
    end

    it 'returns completed task count' do
      create(:task, list: list, creator: user, status: :done)
      create(:task, list: list, creator: user, status: :pending)

      expect(list.completed_task_count).to eq(1)
    end

    it 'returns completion rate' do
      create(:task, list: list, creator: user, status: :done)
      create(:task, list: list, creator: user, status: :pending)

      expect(list.completion_rate).to eq(50.0)
    end

    it 'returns zero completion rate for empty list' do
      expect(list.completion_rate).to eq(0.0)
    end

    it 'returns overdue task count' do
      create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :pending)
      create(:task, list: list, creator: user, due_at: 1.hour.from_now, status: :pending)

      expect(list.overdue_task_count).to eq(1)
    end

    it 'returns recent activity' do
      task = create(:task, list: list, creator: user, created_at: 1.hour.ago)
      expect(list.recent_activity).to include(task)
    end

    it 'returns summary' do
      create(:task, list: list, creator: user, status: :done)
      create(:task, list: list, creator: user, status: :pending)

      summary = list.summary
      expect(summary).to include(:id, :name, :description, :task_count, :completed_task_count, :completion_rate)
    end
  end

  describe 'scopes' do
    it 'has public scope' do
      public_list = create(:list, user: user, visibility: "public")
      private_list = create(:list, user: user, visibility: "private")

      expect(List.public).to include(public_list)
      expect(List.public).not_to include(private_list)
    end

    it 'has private scope' do
      public_list = create(:list, user: user, visibility: "public")
      private_list = create(:list, user: user, visibility: "private")

      expect(List.private).to include(private_list)
      expect(List.private).not_to include(public_list)
    end

    it 'has shared scope' do
      shared_list = create(:list, user: user, visibility: "shared")
      private_list = create(:list, user: user, visibility: "private")

      expect(List.shared).to include(shared_list)
      expect(List.shared).not_to include(private_list)
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
  end

  describe 'permissions' do
    let(:other_user) { create(:user, email: "other@example.com") }
    let(:coach) { create(:user, role: "coach") }
    let(:client) { create(:user, role: "client") }

    it 'allows owner full access' do
      expect(list.can_view?(user)).to be true
      expect(list.can_edit?(user)).to be true
      expect(list.can_add_items_by?(user)).to be true
      expect(list.can_delete_items_by?(user)).to be true
    end

    it 'allows editor full access' do
      create(:membership, list: list, user: other_user, role: "editor")

      expect(list.can_view?(other_user)).to be true
      expect(list.can_edit?(other_user)).to be true
      expect(list.can_add_items_by?(other_user)).to be true
      expect(list.can_delete_items_by?(other_user)).to be true
    end

    it 'allows viewer read-only access' do
      create(:membership, list: list, user: other_user, role: "viewer")

      expect(list.can_view?(other_user)).to be true
      expect(list.can_edit?(other_user)).to be false
      expect(list.can_add_items_by?(other_user)).to be false
      expect(list.can_delete_items_by?(other_user)).to be false
    end

    it 'denies access to non-members' do
      expect(list.can_view?(other_user)).to be false
      expect(list.can_edit?(other_user)).to be false
      expect(list.can_add_items_by?(other_user)).to be false
      expect(list.can_delete_items_by?(other_user)).to be false
    end

    it 'handles coaching relationships' do
      create(:coaching_relationship, coach: coach, client: client, status: :active)
      create(:membership, list: list, user: coach, role: "editor")

      expect(list.coach?(coach)).to be true
      expect(list.coach?(client)).to be false
    end
  end

  describe 'statistics' do
    it 'calculates statistics correctly' do
      create(:task, list: list, creator: user, status: :done, created_at: 1.day.ago)
      create(:task, list: list, creator: user, status: :pending, created_at: 1.hour.ago)
      create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago)

      stats = list.statistics
      expect(stats[:total_tasks]).to eq(3)
      expect(stats[:completed_tasks]).to eq(1)
      expect(stats[:pending_tasks]).to eq(2)
      expect(stats[:overdue_tasks]).to eq(1)
      expect(stats[:completion_rate]).to eq(33.33)
    end

    it 'handles empty list statistics' do
      stats = list.statistics
      expect(stats[:total_tasks]).to eq(0)
      expect(stats[:completed_tasks]).to eq(0)
      expect(stats[:pending_tasks]).to eq(0)
      expect(stats[:overdue_tasks]).to eq(0)
      expect(stats[:completion_rate]).to eq(0.0)
    end
  end
end
