require "test_helper"

class ListTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
  end

  test "should create list with valid attributes" do
    list = List.new(
      name: "New List",
      description: "A new list",
      owner: @user
    )
    assert list.valid?
    assert list.save
  end

  test "should not create list without name" do
    list = List.new(
      description: "A list without name",
      owner: @user
    )
    assert_not list.valid?
    assert_includes list.errors[:name], "can't be blank"
  end

  test "should not create list without user" do
    list = List.new(
      name: "List without user",
      description: "A list without user"
    )
    assert_not list.valid?
    assert_includes list.errors[:user], "must exist"
  end

  test "should have tasks" do
    task1 = create_test_task(@list)
    task2 = create_test_task(@list)
    
    assert_includes @list.tasks, task1
    assert_includes @list.tasks, task2
    assert_equal 2, @list.tasks.count
  end

  test "should have memberships" do
    other_user = create_test_user(email: "member@example.com")
    membership = @list.memberships.create!(user: other_user, role: "editor")
    
    assert_includes @list.memberships, membership
    assert_includes @list.members, other_user
  end

  test "should check if user can edit list" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @list.can_edit?(@user)
    assert_not @list.can_edit?(other_user)
  end

  test "should check if user can add items to list" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @list.can_add_items?(@user)
    assert_not @list.can_add_items?(other_user)
  end

  test "should check if user can add items by user" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @list.can_add_items_by?(@user)
    assert_not @list.can_add_items_by?(other_user)
  end

  test "should handle list sharing" do
    other_user = create_test_user(email: "shared@example.com")
    share = @list.list_shares.create!(
      user: other_user,
      email: other_user.email,
      role: "viewer"
    )
    
    assert_includes @list.list_shares, share
    assert_includes @list.shared_users, other_user
  end

  test "should check if user is member" do
    other_user = create_test_user(email: "member@example.com")
    @list.memberships.create!(user: other_user, role: "editor")
    
    assert @list.member?(other_user)
    assert_not @list.member?(@user) # Owner is not a member
  end

  test "should check if user is owner" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @list.owner?(@user)
    assert_not @list.owner?(other_user)
  end

  test "should get accessible lists for user" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    
    # User should only see their own lists
    accessible_lists = List.accessible_by(@user)
    assert_includes accessible_lists, @list
    assert_not_includes accessible_lists, other_list
  end

  test "should handle soft delete" do
    assert_not @list.deleted?
    @list.soft_delete!
    assert @list.deleted?
    assert_not_nil @list.deleted_at
  end

  test "should restore soft deleted list" do
    @list.soft_delete!
    @list.restore!
    assert_not @list.deleted?
    assert_nil @list.deleted_at
  end

  test "should handle coaching relationships" do
    coach = create_test_user(role: "coach")
    relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "client",
      status: "active"
    )
    
    # Add coach as member
    @list.memberships.create!(
      user: coach,
      role: "editor",
      coaching_relationship: relationship
    )
    
    assert @list.coach?(coach)
    assert_includes @list.coaches, coach
  end

  test "should get list statistics" do
    # Clear existing tasks to avoid interference
    @list.tasks.destroy_all
    
    # Create some tasks
    create_test_task(@list, status: :pending)
    create_test_task(@list, status: :done)
    create_test_task(@list, status: :pending, due_at: 1.hour.ago)
    
    stats = @list.statistics
    assert_equal 3, stats[:total_tasks]
    assert_equal 1, stats[:completed_tasks]
    assert_equal 2, stats[:pending_tasks]
    assert_equal 1, stats[:overdue_tasks]
  end

  test "should handle list permissions" do
    other_user = create_test_user(email: "member@example.com")
    membership = @list.memberships.create!(
      user: other_user,
      role: "editor"
    )
    
    assert membership.can_edit?
    assert membership.can_add_items?
    assert_not membership.can_delete_items?
  end

  test "should validate list name length" do
    @list.name = "a" * 256 # Too long
    assert_not @list.valid?
    assert_includes @list.errors[:name], "is too long"
  end

  test "should handle list description" do
    @list.description = "Updated description"
    assert @list.valid?
    assert @list.save
    assert_equal "Updated description", @list.description
  end

  test "should get recent tasks" do
    # Clear existing tasks to avoid interference
    @list.tasks.destroy_all
    
    old_task = create_test_task(@list, created_at: 2.days.ago)
    recent_task = create_test_task(@list, created_at: 1.hour.ago)
    
    recent_tasks = @list.recent_tasks
    assert_includes recent_tasks, recent_task
    assert_not_includes recent_tasks, old_task
  end

  test "should get overdue tasks" do
    overdue_task = create_test_task(@list, 
      due_at: 1.hour.ago, 
      status: :pending
    )
    future_task = create_test_task(@list, 
      due_at: 1.hour.from_now, 
      status: :pending
    )
    
    overdue_tasks = @list.overdue_tasks
    assert_includes overdue_tasks, overdue_task
    assert_not_includes overdue_tasks, future_task
  end

  test "should handle list archiving" do
    assert_not @list.archived?
    @list.archive!
    assert @list.archived?
    assert_not_nil @list.archived_at
  end

  test "should unarchive list" do
    @list.archive!
    @list.unarchive!
    assert_not @list.archived?
    assert_nil @list.archived_at
  end

  test "should get active lists" do
    archived_list = create_test_list(@user)
    archived_list.archive!
    
    active_lists = List.active.reject(&:archived?)
    assert_includes active_lists, @list
    assert_not_includes active_lists, archived_list
  end

  test "should handle list visibility" do
    @list.update!(visibility: "private")
    assert @list.private?
    
    @list.update!(visibility: "public")
    assert @list.public?
  end

  test "should get list completion rate" do
    # Create tasks with different statuses
    create_test_task(@list, status: :done)
    create_test_task(@list, status: :done)
    create_test_task(@list, status: :pending)
    
    completion_rate = @list.completion_rate
    assert_equal 66.67, completion_rate.round(2)
  end

  test "should handle list tags" do
    @list.update!(tags: ["work", "urgent"])
    assert_includes @list.tags, "work"
    assert_includes @list.tags, "urgent"
  end

  test "should get lists by tag" do
    work_list = create_test_list(@user, tags: ["work"])
    personal_list = create_test_list(@user, tags: ["personal"])
    
    work_lists = List.tagged_with("work")
    assert_includes work_lists, work_list
    assert_not_includes work_lists, personal_list
  end

  test "should handle list notifications" do
    other_user = create_test_user(email: "member@example.com")
    membership = @list.memberships.create!(
      user: other_user,
      role: "editor"
    )
    
    assert membership.receive_notifications?
    assert @list.should_notify?(other_user)
  end

  test "should get list activity" do
    # Create some tasks and events
    task = create_test_task(@list)
    task.complete!
    
    activity = @list.recent_activity
    assert activity.any? { |item| item.is_a?(Task) }
  end
end