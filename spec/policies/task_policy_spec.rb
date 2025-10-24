# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskPolicy, type: :policy do
  let(:user) { create(:user, email: "task_policy_user@example.com") }
  let(:list) { create(:list, owner: user) }
  let(:task) { create(:task, list: list) }
  
  # Create another user for testing permissions
  let(:other_user) { create(:user, email: "task_policy_other@example.com") }
  
  # Create a coach user
  let(:coach) { create(:user, email: "task_policy_coach@example.com", role: "coach") }
  
  # Create a client user
  let(:client) { create(:user, email: "task_policy_client@example.com") }
  
  # Create coaching relationship
  let(:coaching_relationship) do
    create(:coaching_relationship,
           coach: coach,
           client: client,
           status: :active,
           invited_by: coach)
  end
  
  # Create shared list for coach
  let(:shared_list) { create(:list, owner: client) }
  let(:shared_task) { create(:task, list: shared_list, creator: client) }
  
  before do
    # Share list with coach
    shared_list.share_with!(coach, {
      can_view: true,
      can_edit: true,
      can_add_items: true,
      can_delete_items: true
    })
    
    # Create membership for the coach in the shared list using existing coaching relationship
    create(:membership,
           user: coach,
           list: shared_list,
           role: "editor",
           coaching_relationship: coaching_relationship)
  end

  # ==========================================
  # BASIC PERMISSION TESTS
  # ==========================================

  describe '#show?' do
    it 'allows owner to view own tasks' do
      policy = described_class.new(user, task)
      expect(policy.show?).to be true
    end
  end

  describe '#update?' do
    it 'allows owner to update own tasks' do
      policy = described_class.new(user, task)
      expect(policy.update?).to be true
    end
  end

  describe '#destroy?' do
    it 'allows owner to delete own tasks' do
      policy = described_class.new(user, task)
      expect(policy.destroy?).to be true
    end
  end

  describe '#complete?' do
    it 'allows owner to complete own tasks' do
      policy = described_class.new(user, task)
      expect(policy.complete?).to be true
    end
  end

  describe '#reassign?' do
    it 'allows owner to reassign own tasks' do
      policy = described_class.new(user, task)
      expect(policy.reassign?).to be true
    end
  end

  describe '#change_visibility?' do
    it 'allows owner to change visibility of own tasks' do
      policy = described_class.new(user, task)
      expect(policy.change_visibility?).to be true
    end
  end

  # ==========================================
  # SHARED USER PERMISSION TESTS
  # ==========================================

  describe 'shared user permissions' do
    let(:shared_user) { create(:user, email: "task_policy_shared@example.com") }

    before do
      list.share_with!(shared_user, {
        can_view: true,
        can_edit: false,
        can_add_items: false,
        can_delete_items: false
      })
    end

    it 'allows shared user with can_view permission to view tasks' do
      policy = described_class.new(shared_user, task)
      expect(policy.show?).to be true
    end

    it 'does not allow shared user without can_edit to update tasks' do
      policy = described_class.new(shared_user, task)
      expect(policy.update?).to be false
      expect(policy.complete?).to be false
      expect(policy.reassign?).to be false
    end

    it 'does not allow shared user without can_delete_items to delete tasks' do
      policy = described_class.new(shared_user, task)
      expect(policy.destroy?).to be false
    end
  end

  describe 'shared user with edit permissions' do
    let(:editor_user) { create(:user, email: "task_policy_editor@example.com") }

    before do
      list.share_with!(editor_user, {
        can_view: true,
        can_edit: true,
        can_add_items: false,
        can_delete_items: false
      })
    end

    it 'allows shared user with can_edit permission to update tasks' do
      policy = described_class.new(editor_user, task)
      expect(policy.update?).to be true
      expect(policy.complete?).to be true
      expect(policy.reassign?).to be true
    end
  end

  describe 'shared user with delete permissions' do
    let(:deleter_user) { create(:user, email: "task_policy_deleter@example.com") }

    before do
      list.share_with!(deleter_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: true
      })
    end

    it 'allows shared user with can_delete_items to delete tasks' do
      policy = described_class.new(deleter_user, task)
      expect(policy.destroy?).to be true
    end
  end

  # ==========================================
  # COACH PERMISSION TESTS
  # ==========================================

  describe 'coach permissions' do
    it 'allows coach to view client\'s tasks' do
      policy = described_class.new(coach, shared_task)
      expect(policy.show?).to be true
    end

    it 'does not allow coach to edit client\'s tasks' do
      policy = described_class.new(coach, shared_task)
      expect(policy.show?).to be true # Can view
      expect(policy.update?).to be false # Cannot update
      expect(policy.complete?).to be false # Cannot complete
      expect(policy.reassign?).to be false # Cannot reassign
      expect(policy.destroy?).to be false # Cannot delete
    end

    it 'allows coach to change visibility of client\'s tasks' do
      policy = described_class.new(coach, shared_task)
      expect(policy.change_visibility?).to be true
    end
  end

  describe 'coach with hidden tasks' do
    let(:hidden_task) do
      create(:task,
             list: shared_list,
             creator: client,
             visibility: :hidden_from_coaches)
    end

    it 'does not allow coach to view tasks marked hidden_from_coaches' do
      policy = described_class.new(coach, hidden_task)
      expect(policy.show?).to be false
    end
  end

  describe 'coach with private tasks' do
    let(:private_task) do
      create(:task,
             list: shared_list,
             creator: client,
             visibility: :private_task)
    end

    it 'does not allow coach to view tasks with private_task visibility' do
      policy = described_class.new(coach, private_task)
      expect(policy.show?).to be false
    end
  end

  # ==========================================
  # VISIBILITY TESTS
  # ==========================================

  describe 'task visibility' do
    let(:private_task) do
      create(:task,
             list: list,
             creator: user,
             visibility: :private_task)
    end

    it 'does not allow other users to view private tasks' do
      policy = described_class.new(other_user, private_task)
      expect(policy.show?).to be false
    end

    it 'allows owner to view private tasks' do
      policy = described_class.new(user, private_task)
      expect(policy.show?).to be true
    end
  end

  describe 'deleted tasks' do
    let(:deleted_task) do
      create(:task,
             list: list,
             creator: user,
             status: :deleted,
             deleted_at: Time.current)
    end

    it 'allows owner to view deleted tasks' do
      policy = described_class.new(user, deleted_task)
      expect(policy.show?).to be true
    end

    it 'does not allow other users to view deleted tasks' do
      policy = described_class.new(other_user, deleted_task)
      expect(policy.show?).to be false
    end
  end

  describe 'deleted lists' do
    before do
      list.soft_delete!
    end

    it 'does not allow users to view tasks in deleted lists' do
      policy = described_class.new(user, task)
      expect(policy.show?).to be false
    end

    it 'does not allow users to perform actions on tasks in deleted lists' do
      policy = described_class.new(user, task)
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.complete?).to be false
      expect(policy.reassign?).to be false
    end
  end

  # ==========================================
  # TASK CREATION TESTS
  # ==========================================

  describe '#create?' do
    it 'allows user to create tasks in lists they have access to' do
      new_task = Task.new(
        list: list,
        creator: user,
        title: "New Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(user, new_task)
      expect(policy.create?).to be true
    end

    it 'allows shared user to create tasks if they have can_add_items permission' do
      shared_user = create(:user, email: "task_policy_adder@example.com")
      list.share_with!(shared_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false
      })
      
      new_task = Task.new(
        list: list,
        creator: shared_user,
        title: "New Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(shared_user, new_task)
      expect(policy.create?).to be true
    end

    it 'does not allow shared user to create tasks without can_add_items permission' do
      shared_user = create(:user, email: "task_policy_no_add@example.com")
      list.share_with!(shared_user, {
        can_view: true,
        can_edit: false,
        can_add_items: false,
        can_delete_items: false
      })
      
      new_task = Task.new(
        list: list,
        creator: shared_user,
        title: "New Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(shared_user, new_task)
      expect(policy.create?).to be false
    end

    it 'does not allow user to create tasks in lists they don\'t have access to' do
      other_list = create(:list, owner: other_user)
      new_task = Task.new(
        list: other_list,
        creator: user,
        title: "New Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(user, new_task)
      expect(policy.create?).to be false
    end
  end

  # ==========================================
  # VISIBILITY CHANGE TESTS
  # ==========================================

  describe 'visibility changes' do
    it 'allows task creator to change visibility' do
      policy = described_class.new(user, task)
      expect(policy.change_visibility?).to be true
    end

    it 'allows list owner to change task visibility' do
      other_user = create(:user, email: "task_policy_other_creator@example.com")
      list.share_with!(other_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false
      })
      
      other_task = create(:task, list: list, creator: other_user)
      
      policy = described_class.new(user, other_task)
      expect(policy.change_visibility?).to be true
    end

    it 'does not allow shared user to change task visibility' do
      shared_user = create(:user, email: "task_policy_no_visibility@example.com")
      list.share_with!(shared_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: true
      })
      
      policy = described_class.new(shared_user, task)
      expect(policy.change_visibility?).to be false
    end
  end

  # ==========================================
  # SCOPE TESTS
  # ==========================================

  describe 'scope' do
    let(:visible_task) do
      create(:task,
             list: list,
             creator: user,
             visibility: :visible_to_all)
    end
    
    let(:hidden_task) do
      create(:task,
             list: list,
             creator: user,
             visibility: :hidden_from_coaches)
    end

    it 'returns tasks visible to user' do
      visible_task
      hidden_task
      
      # Test scope for owner
      scope = described_class::Scope.new(user, Task.all).resolve
      expect(scope).to include(visible_task)
      expect(scope).to include(hidden_task)
      
      # Test scope for other user (should only see visible tasks)
      list.share_with!(other_user, {
        can_view: true,
        can_edit: false,
        can_add_items: false,
        can_delete_items: false
      })
      
      scope = described_class::Scope.new(other_user, Task.all).resolve
      expect(scope).to include(visible_task)
      expect(scope).not_to include(hidden_task)
    end

    it 'filters tasks based on list access' do
      # Force creation of user's task before resolving scope
      task
      
      other_list = create(:list, owner: other_user)
      other_task = create(:task, list: other_list, creator: other_user)
      
      # Test scope for user (should only see tasks in their accessible lists)
      scope = described_class::Scope.new(user, Task.all).resolve
      expect(scope).to include(task)
      expect(scope).not_to include(other_task)
    end
  end

  # ==========================================
  # EDGE CASES TESTS
  # ==========================================

  describe 'edge cases' do
    it 'does not allow nil user to perform any actions' do
      policy = described_class.new(nil, task)
      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.complete?).to be false
      expect(policy.reassign?).to be false
      expect(policy.change_visibility?).to be false
    end

    it 'does not allow user to perform actions on nil task' do
      policy = described_class.new(user, nil)
      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.complete?).to be false
      expect(policy.reassign?).to be false
      expect(policy.change_visibility?).to be false
    end
  end

  # ==========================================
  # TASK STATUS TESTS
  # ==========================================

  describe 'task status permissions' do
    it 'allows user to complete pending tasks' do
      policy = described_class.new(user, task)
      expect(policy.complete?).to be true
    end

    it 'allows user to complete in_progress tasks' do
      task.update!(status: :in_progress)
      policy = described_class.new(user, task)
      expect(policy.complete?).to be true
    end

    it 'allows user to reassign pending tasks' do
      policy = described_class.new(user, task)
      expect(policy.reassign?).to be true
    end

    it 'allows user to reassign in_progress tasks' do
      task.update!(status: :in_progress)
      policy = described_class.new(user, task)
      expect(policy.reassign?).to be true
    end
  end

  # ==========================================
  # PERMISSION COMBINATION TESTS
  # ==========================================

  describe 'permission combinations' do
    it 'allows user with full permissions to perform all actions' do
      full_user = create(:user, email: "full@example.com")
      list.share_with!(full_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: true
      })
      
      policy = described_class.new(full_user, task)
      expect(policy.show?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
      expect(policy.complete?).to be true
      expect(policy.reassign?).to be true
      # Note: change_visibility is not based on list permissions
      expect(policy.change_visibility?).to be false
    end

    it 'limits user with view-only permissions' do
      viewer = create(:user, email: "viewer@example.com")
      list.share_with!(viewer, {
        can_view: true,
        can_edit: false,
        can_add_items: false,
        can_delete_items: false
      })
      
      policy = described_class.new(viewer, task)
      expect(policy.show?).to be true # Can view
      expect(policy.update?).to be false # Cannot update
      expect(policy.destroy?).to be false # Cannot delete
      expect(policy.complete?).to be false # Cannot complete
      expect(policy.reassign?).to be false # Cannot reassign
      expect(policy.change_visibility?).to be false # Cannot change visibility
    end

    it 'does not allow user without list access to perform any actions' do
      no_access_user = create(:user, email: "no_access@example.com")
      
      policy = described_class.new(no_access_user, task)
      expect(policy.show?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.complete?).to be false
      expect(policy.reassign?).to be false
      expect(policy.change_visibility?).to be false
    end
  end

  # ==========================================
  # TASK VISIBILITY TESTS
  # ==========================================

  describe 'task visibility levels' do
    it 'allows all users to see visible_to_all tasks' do
      task.update!(visibility: :visible_to_all)
      
      # Owner can see it
      policy = described_class.new(user, task)
      expect(policy.show?).to be true
      
      # Shared user can see it
      shared_user = create(:user, email: "shared_visible@example.com")
      list.share_with!(shared_user, { can_view: true })
      policy = described_class.new(shared_user, task)
      expect(policy.show?).to be true
    end

    it 'does not allow coaches to see hidden_from_coaches tasks' do
      task.update!(visibility: :hidden_from_coaches)
      
      # Owner can see it
      policy = described_class.new(user, task)
      expect(policy.show?).to be true
      
      # Coach cannot see it
      policy = described_class.new(coach, task)
      expect(policy.show?).to be false
    end

    it 'only allows creator and list owner to see private_task tasks' do
      task.update!(visibility: :private_task)
      
      # Owner can see it
      policy = described_class.new(user, task)
      expect(policy.show?).to be true
      
      # Other users cannot see it
      policy = described_class.new(other_user, task)
      expect(policy.show?).to be false
    end
  end

  # ==========================================
  # INTEGRATION TESTS
  # ==========================================

  describe 'complete workflow for task permissions' do
    it 'allows owner to perform all actions on their tasks' do
      # 1. User creates a task
      new_task = Task.new(
        list: list,
        creator: user,
        title: "Workflow Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(user, new_task)
      
      # 2. User can create the task
      expect(policy.create?).to be true
      
      # 3. User can view the task
      expect(policy.show?).to be true
      
      # 4. User can update the task
      expect(policy.update?).to be true
      
      # 5. User can complete the task
      expect(policy.complete?).to be true
      
      # 6. User can reassign the task
      expect(policy.reassign?).to be true
      
      # 7. User can change visibility
      expect(policy.change_visibility?).to be true
      
      # 8. User can delete the task
      expect(policy.destroy?).to be true
    end

    it 'allows shared user workflow for task permissions' do
      # Create a shared user with edit permissions
      shared_user = create(:user, email: "workflow_shared@example.com")
      list.share_with!(shared_user, {
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false
      })
      
      # 1. Shared user can create tasks
      new_task = Task.new(
        list: list,
        creator: shared_user,
        title: "Shared Workflow Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
      
      policy = described_class.new(shared_user, new_task)
      
      # 2. Shared user can create the task
      expect(policy.create?).to be true
      
      # 3. Shared user can view the task
      expect(policy.show?).to be true
      
      # 4. Shared user can update the task
      expect(policy.update?).to be true
      
      # 5. Shared user can complete the task
      expect(policy.complete?).to be true
      
      # 6. Shared user can reassign the task
      expect(policy.reassign?).to be true
      
      # 7. Shared user can change visibility (is creator)
      expect(policy.change_visibility?).to be true
      
      # 8. Shared user cannot delete the task (no delete permission)
      expect(policy.destroy?).to be false
    end
  end
end
