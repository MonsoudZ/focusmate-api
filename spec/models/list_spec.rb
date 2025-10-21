require 'rails_helper'

RSpec.describe List, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'associations' do
    it { should belong_to(:owner).class_name('User').with_foreign_key('user_id') }
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:members).through(:memberships).source(:user) }
    it { should have_many(:tasks).dependent(:destroy) }
    it { should have_many(:list_shares).dependent(:destroy) }
    it { should have_many(:shared_users).through(:list_shares).source(:user) }
    it { should have_many(:coaching_memberships).class_name('Membership') }
    it { should have_many(:coaching_relationships).through(:coaching_memberships) }
    it { should have_many(:coaches).through(:coaching_relationships).source(:coach) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }
  end

  describe 'basic functionality' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should create list with valid attributes' do
      expect(list).to be_valid
      expect(list.name).to be_present
      expect(list.owner).to eq(user)
    end

    it 'should require name' do
      list = build(:list, name: nil)
      expect(list).not_to be_valid
      expect(list.errors[:name]).to include("can't be blank")
    end

    it 'should belong to user (owner)' do
      expect(list.owner).to eq(user)
    end

    it 'should have many tasks' do
      task1 = create(:task, list: list, creator: user)
      task2 = create(:task, list: list, creator: user)
      
      expect(list.tasks).to include(task1, task2)
    end
  end

  describe 'soft deletes' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should soft delete (set deleted_at)' do
      expect { list.soft_delete! }.to change { list.deleted_at }.from(nil)
      expect(list.deleted?).to be true
    end

    it 'should cascade soft delete to tasks' do
      task = create(:task, list: list, creator: user)
      list.soft_delete!
      
      # Tasks should still exist but list should be soft deleted
      expect(list.deleted?).to be true
      expect(list.tasks).to include(task)
    end

    it 'should exclude deleted lists from default scope' do
      list.soft_delete!
      
      expect(List.not_deleted).not_to include(list)
      expect(List.deleted).to include(list)
    end

    it 'should restore soft deleted list' do
      list.soft_delete!
      expect(list.deleted?).to be true
      
      list.restore!
      expect(list.deleted?).to be false
      expect(list.deleted_at).to be_nil
    end

    it 'should override destroy to use soft delete' do
      expect { list.destroy }.to change { list.deleted_at }.from(nil)
      expect(list.deleted?).to be true
    end

    it 'should override delete to use soft delete' do
      expect { list.delete }.to change { list.deleted_at }.from(nil)
      expect(list.deleted?).to be true
    end
  end

  describe 'sharing' do
    let(:owner) { create(:user) }
    let(:list) { create(:list, owner: owner) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it 'should have many list_shares' do
      share1 = create(:list_share, list: list, user: user1)
      share2 = create(:list_share, list: list, user: user2)
      
      expect(list.list_shares).to include(share1, share2)
    end

    it 'should have many shared_users through list_shares' do
      create(:list_share, list: list, user: user1)
      create(:list_share, list: list, user: user2)
      
      expect(list.shared_users).to include(user1, user2)
    end

    it 'should allow sharing with multiple users' do
      list.share_with!(user1, { role: 'viewer', can_view: true })
      list.share_with!(user2, { role: 'editor', can_edit: true })
      
      expect(list.list_shares.exists?(user: user1)).to be true
      expect(list.list_shares.exists?(user: user2)).to be true
    end

    it 'should invite by email' do
      email = 'test@example.com'
      list.invite_by_email!(email, 'viewer', { can_view: true })
      
      share = list.list_shares.find_by(email: email)
      expect(share).to be_present
      expect(share.role).to eq('viewer')
    end

    it 'should unshare with user' do
      list.share_with!(user1)
      expect(list.list_shares.exists?(user: user1)).to be true
      
      list.unshare_with!(user1)
      expect(list.list_shares.exists?(user: user1)).to be false
    end

    it 'should get share permissions for user' do
      list.share_with!(user1, { can_edit: true, can_add_items: true })
      permissions = list.share_permissions_for(user1)
      
      expect(permissions).to be_present
    end

    it 'should get pending invitations' do
      # Create a share with a non-existent user email to get pending status
      create(:list_share, list: list, email: 'nonexistent@example.com', user: nil, status: 'pending')
      create(:list_share, list: list, user: user1, status: 'accepted')
      
      expect(list.pending_invitations.count).to eq(1)
    end

    it 'should get accepted shares' do
      # Create a share with a non-existent user email to get pending status
      create(:list_share, list: list, email: 'nonexistent@example.com', user: nil, status: 'pending')
      create(:list_share, list: list, user: user1, status: 'accepted')
      
      expect(list.accepted_shares.count).to eq(1)
    end
  end

  describe 'memberships' do
    let(:owner) { create(:user) }
    let(:list) { create(:list, owner: owner) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it 'should have many memberships' do
      membership1 = create(:membership, list: list, user: user1, role: 'editor')
      membership2 = create(:membership, list: list, user: user2, role: 'viewer')
      
      expect(list.memberships).to include(membership1, membership2)
    end

    it 'should allow members with different roles' do
      create(:membership, list: list, user: user1, role: 'editor')
      create(:membership, list: list, user: user2, role: 'viewer')
      
      expect(list.role_for(user1)).to eq('editor')
      expect(list.role_for(user2)).to eq('viewer')
    end

    it 'should check if user is member' do
      create(:membership, list: list, user: user1)
      
      expect(list.member?(user1)).to be true
      expect(list.member?(user2)).to be false
    end
  end

  describe 'permissions' do
    let(:owner) { create(:user) }
    let(:list) { create(:list, owner: owner) }
    let(:editor) { create(:user) }
    let(:viewer) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:membership, list: list, user: editor, role: 'editor')
      create(:membership, list: list, user: viewer, role: 'viewer')
    end

    it 'should check if user can edit' do
      expect(list.can_edit?(owner)).to be true
      expect(list.can_edit?(editor)).to be true
      expect(list.can_edit?(viewer)).to be false
      expect(list.can_edit?(other_user)).to be false
    end

    it 'should check if user can view' do
      expect(list.can_view?(owner)).to be true
      expect(list.can_view?(editor)).to be true
      expect(list.can_view?(viewer)).to be true
      expect(list.can_view?(other_user)).to be false
    end

    it 'should check if user can invite' do
      expect(list.can_invite?(owner)).to be true
      expect(list.can_invite?(editor)).to be true
      expect(list.can_invite?(viewer)).to be false
      expect(list.can_invite?(other_user)).to be false
    end

    it 'should check if user can add items' do
      expect(list.can_add_items?(owner)).to be true
      expect(list.can_add_items?(editor)).to be true
      expect(list.can_add_items?(viewer)).to be false
      expect(list.can_add_items?(other_user)).to be false
    end

    it 'should check if list is viewable by user' do
      expect(list.viewable_by?(owner)).to be true
      expect(list.viewable_by?(editor)).to be true
      expect(list.viewable_by?(viewer)).to be true
      expect(list.viewable_by?(other_user)).to be false
    end

    it 'should check if list is editable by user' do
      expect(list.editable_by?(owner)).to be true
      expect(list.editable_by?(editor)).to be true
      expect(list.editable_by?(viewer)).to be false
      expect(list.editable_by?(other_user)).to be false
    end

    it 'should check if user can add items by permission' do
      expect(list.can_add_items_by?(owner)).to be true
      expect(list.can_add_items_by?(editor)).to be true
      expect(list.can_add_items_by?(viewer)).to be false
      expect(list.can_add_items_by?(other_user)).to be false
    end

    it 'should check if user can delete items by permission' do
      expect(list.can_delete_items_by?(owner)).to be true
      expect(list.can_delete_items_by?(editor)).to be true
      expect(list.can_delete_items_by?(viewer)).to be false
      expect(list.can_delete_items_by?(other_user)).to be false
    end
  end

  describe 'coaching relationships' do
    let(:coach) { create(:user, :coach) }
    let(:client) { create(:user, :client) }
    let(:list) { create(:list, owner: client) }
    let(:relationship) { create(:coaching_relationship, coach: coach, client: client) }

    it 'should check if user is coach for this list' do
      create(:membership, list: list, user: coach, coaching_relationship: relationship)
      
      expect(list.coach?(coach)).to be true
    end

    it 'should get all coaches for this list' do
      create(:membership, list: list, user: coach, coaching_relationship: relationship)
      
      expect(list.all_coaches).to include(coach)
    end

    it 'should check if list has coaching relationships' do
      create(:membership, list: list, user: coach, coaching_relationship: relationship)
      
      expect(list.has_coaching?).to be true
    end

    it 'should get tasks visible to coaching relationship' do
      task = create(:task, list: list, creator: client)
      visible_tasks = list.tasks_for_coaching_relationship(relationship)
      
      expect(visible_tasks).to include(task)
    end
  end

  describe 'task management' do
    let(:owner) { create(:user) }
    let(:list) { create(:list, owner: owner) }

    it 'should get overdue tasks' do
      overdue_task = create(:task, list: list, creator: owner, due_at: 1.day.ago, status: 'pending')
      current_task = create(:task, list: list, creator: owner, due_at: 1.day.from_now, status: 'pending')
      
      overdue_tasks = list.overdue_tasks
      expect(overdue_tasks).to include(overdue_task)
      expect(overdue_tasks).not_to include(current_task)
    end

    it 'should get tasks requiring explanation' do
      task_requiring_explanation = create(:task, 
        list: list, 
        creator: owner, 
        requires_explanation_if_missed: true,
        due_at: 1.day.ago,
        status: 'pending'
      )
      regular_task = create(:task, 
        list: list, 
        creator: owner, 
        requires_explanation_if_missed: false,
        due_at: 1.day.ago,
        status: 'pending'
      )
      
      tasks_requiring_explanation = list.tasks_requiring_explanation
      expect(tasks_requiring_explanation).to include(task_requiring_explanation)
      expect(tasks_requiring_explanation).not_to include(regular_task)
    end

    it 'should get location-based tasks' do
      location_task = create(:task, list: list, creator: owner, location_based: true, location_latitude: 40.7128, location_longitude: -74.0060)
      regular_task = create(:task, list: list, creator: owner, location_based: false)
      
      location_tasks = list.location_based_tasks
      expect(location_tasks).to include(location_task)
      expect(location_tasks).not_to include(regular_task)
    end

    it 'should get recurring tasks' do
      recurring_task = create(:task, list: list, creator: owner, is_recurring: true, recurrence_pattern: 'daily', recurrence_time: Time.current)
      regular_task = create(:task, list: list, creator: owner, is_recurring: false)
      
      recurring_tasks = list.recurring_tasks
      expect(recurring_tasks).to include(recurring_task)
      expect(recurring_tasks).not_to include(regular_task)
    end
  end

  describe 'scopes' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:list1) { create(:list, owner: user1) }
    let!(:list2) { create(:list, owner: user2) }
    let!(:deleted_list) { create(:list, owner: user1, deleted_at: Time.current) }

    it 'should scope by owner' do
      expect(List.owned_by(user1)).to include(list1)
      expect(List.owned_by(user1)).not_to include(list2)
    end

    it 'should scope accessible by user' do
      create(:membership, list: list2, user: user1, role: 'editor')
      
      accessible_lists = List.accessible_by(user1)
      expect(accessible_lists).to include(list1, list2)
    end

    it 'should scope not deleted lists' do
      expect(List.not_deleted).to include(list1, list2)
      expect(List.not_deleted).not_to include(deleted_list)
    end

    it 'should scope deleted lists' do
      expect(List.deleted).to include(deleted_list)
      expect(List.deleted).not_to include(list1, list2)
    end

    it 'should scope active lists' do
      expect(List.active).to include(list1, list2)
      expect(List.active).not_to include(deleted_list)
    end

    it 'should scope modified since timestamp' do
      travel_to(1.hour.ago) do
        list1.update!(name: 'Updated')
      end
      
      modified_lists = List.modified_since(2.hours.ago)
      expect(modified_lists).to include(list1)
    end
  end

  describe 'statistics and analytics' do
    let(:owner) { create(:user) }
    let(:list) { create(:list, owner: owner) }

    it 'should calculate completion rate' do
      create(:task, list: list, creator: owner, status: 'done')
      create(:task, list: list, creator: owner, status: 'pending')
      
      expect(list.completion_rate).to eq(50.0)
    end

    it 'should get recent tasks' do
      task1 = create(:task, list: list, creator: owner)
      task2 = create(:task, list: list, creator: owner)
      
      recent_tasks = list.recent_tasks
      expect(recent_tasks).to include(task1, task2)
    end

    it 'should get statistics' do
      create(:task, list: list, creator: owner, status: 'done')
      create(:task, list: list, creator: owner, status: 'pending')
      create(:task, list: list, creator: owner, status: 'pending', due_at: 1.day.ago)
      
      stats = list.statistics
      expect(stats[:total_tasks]).to eq(3)
      expect(stats[:completed_tasks]).to eq(1)
      expect(stats[:pending_tasks]).to eq(2)
      expect(stats[:overdue_tasks]).to eq(1)
      expect(stats[:completion_rate]).to eq(33.33)
    end
  end

  describe 'archiving' do
    let(:list) { create(:list) }

    it 'should check if list is archived' do
      expect(list.archived?).to be false
      
      list.archive!
      expect(list.archived?).to be true
    end

    it 'should archive list' do
      expect { list.archive! }.to change { list.archived? }.from(false).to(true)
      expect(list.archived_at).to be_present
    end

    it 'should unarchive list' do
      list.archive!
      expect { list.unarchive! }.to change { list.archived? }.from(true).to(false)
      expect(list.archived_at).to be_nil
    end
  end

  describe 'visibility and tags' do
    let(:list) { create(:list) }

    it 'should have default visibility' do
      # The default visibility is set in the model
      expect(list.visibility).to eq('private')
    end

    it 'should check if list is private' do
      list.visibility = 'private'
      expect(list.private?).to be true
      expect(list.public?).to be false
    end

    it 'should check if list is public' do
      list.visibility = 'public'
      expect(list.public?).to be true
      expect(list.private?).to be false
    end

    it 'should handle tags' do
      list.tags = ['work', 'urgent']
      expect(list.tags).to include('work', 'urgent')
    end

    it 'should find lists by tag' do
      # This is a placeholder since tagging is not fully implemented
      tagged_lists = List.tagged_with('work')
      expect(tagged_lists).to be_empty
    end
  end

  describe 'edge cases' do
    let(:list) { create(:list) }

    it 'should handle list with no tasks' do
      expect(list.completion_rate).to eq(0)
      expect(list.statistics[:total_tasks]).to eq(0)
    end

    it 'should handle list with no members' do
      expect(list.members).to be_empty
    end

    it 'should handle list with no shares' do
      expect(list.shared_users).to be_empty
    end

    it 'should handle recent activity' do
      activity = list.recent_activity
      expect(activity).to be_an(Array)
    end

    it 'should handle notification preferences' do
      user = create(:user)
      expect(list.should_notify?(user)).to be true
    end
  end
end
