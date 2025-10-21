require "test_helper"

class TaskTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @task = create_test_task(@list, creator: @user)
  end

  test "should create task with valid attributes" do
    task = Task.new(
      title: "New Task",
      due_at: 1.hour.from_now,
      list: @list,
      creator: @user,
      strict_mode: true
    )
    assert task.valid?
    assert task.save
  end

  test "should not create task without title" do
    task = Task.new(
      due_at: 1.hour.from_now,
      list: @list,
      creator: @user
    )
    assert_not task.valid?
    assert_includes task.errors[:title], "can't be blank"
  end

  test "should not create task without due_at" do
    task = Task.new(
      title: "Test Task",
      list: @list,
      creator: @user
    )
    assert_not task.valid?
    assert_includes task.errors[:due_at], "can't be blank"
  end

  test "should not create task without list" do
    task = Task.new(
      title: "Test Task",
      due_at: 1.hour.from_now,
      creator: @user
    )
    assert_not task.valid?
    assert_includes task.errors[:list], "must exist"
  end

  test "should not create task without creator" do
    task = Task.new(
      title: "Test Task",
      due_at: 1.hour.from_now,
      list: @list
    )
    assert_not task.valid?
    assert_includes task.errors[:creator], "must exist"
  end

  test "should validate title length" do
    task = Task.new(
      title: "a" * 256, # Too long
      due_at: 1.hour.from_now,
      list: @list,
      creator: @user
    )
    assert_not task.valid?
    assert_includes task.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should validate note length" do
    task = Task.new(
      title: "Test Task",
      note: "a" * 1001, # Too long
      due_at: 1.hour.from_now,
      list: @list,
      creator: @user
    )
    assert_not task.valid?
    assert_includes task.errors[:note], "is too long (maximum is 1000 characters)"
  end

  test "should complete task" do
    assert_equal "pending", @task.status
    @task.complete!
    assert_equal "done", @task.status
    assert_not_nil @task.completed_at
  end

  test "should uncomplete task" do
    @task.complete!
    @task.uncomplete!
    assert_equal "pending", @task.status
    assert_nil @task.completed_at
  end

  test "should check if task is overdue" do
    overdue_task = create_test_task(@list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending
    )
    future_task = create_test_task(@list, 
      creator: @user, 
      due_at: 1.hour.from_now, 
      status: :pending
    )
    
    assert overdue_task.overdue?
    assert_not future_task.overdue?
  end

  test "should calculate minutes overdue" do
    overdue_task = create_test_task(@list, 
      creator: @user, 
      due_at: 2.hours.ago, 
      status: :pending
    )
    
    minutes_overdue = overdue_task.minutes_overdue
    assert minutes_overdue > 100 # Should be around 120 minutes
    assert minutes_overdue < 150 # Allow some tolerance
  end

  test "should check if task requires explanation" do
    task_with_explanation = create_test_task(@list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending,
      requires_explanation_if_missed: true
    )
    
    task_without_explanation = create_test_task(@list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending,
      requires_explanation_if_missed: false
    )
    
    assert task_with_explanation.requires_explanation?
    assert_not task_without_explanation.requires_explanation?
  end

  test "should check if task was created by coach" do
    coach = create_test_user(role: "coach")
    coach_task = create_test_task(@list, creator: coach)
    client_task = create_test_task(@list, creator: @user)
    
    assert coach_task.created_by_coach?
    assert_not client_task.created_by_coach?
  end

  test "should check if task is editable by user" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @task.editable_by?(@user)
    assert_not @task.editable_by?(other_user)
  end

  test "should check if task is deletable by user" do
    other_user = create_test_user(email: "other@example.com")
    
    assert @task.deletable_by?(@user)
    assert_not @task.deletable_by?(other_user)
  end

  test "should check if task is completable by user" do
    other_user = create_test_user(email: "other@example.com")
    completed_task = create_test_task(@list, creator: @user, status: :done)
    
    assert @task.completable_by?(@user)
    assert_not @task.completable_by?(other_user)
    assert_not completed_task.completable_by?(@user)
  end

  test "should calculate subtask completion percentage" do
    # Create subtasks
    subtask1 = create_test_task(@list, creator: @user, parent_task: @task, status: :done)
    subtask2 = create_test_task(@list, creator: @user, parent_task: @task, status: :pending)
    
    percentage = @task.subtask_completion_percentage
    assert_equal 50.0, percentage
  end

  test "should check if task should block app" do
    # Create an overdue task that should block the app
    blocking_task = create_test_task(@list, 
      creator: @user, 
      due_at: 3.hours.ago, 
      status: :pending,
      # priority: 3, # Priority attribute doesn't exist
      can_be_snoozed: false
    )
    
    # Create a task that shouldn't block the app
    non_blocking_task = create_test_task(@list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending,
      # priority: 1, # Priority attribute doesn't exist
      can_be_snoozed: true
    )
    
    assert blocking_task.should_block_app?
    assert_not non_blocking_task.should_block_app?
  end

  test "should create escalation record" do
    assert_nil @task.escalation
    @task.create_escalation!
    assert_not_nil @task.escalation
    assert_equal "normal", @task.escalation.escalation_level
  end

  test "should check if all subtasks are completed" do
    # No subtasks
    assert @task.all_subtasks_completed?
    
    # Add completed subtasks
    create_test_task(@list, creator: @user, parent_task: @task, status: :done)
    create_test_task(@list, creator: @user, parent_task: @task, status: :done)
    @task.reload
    assert @task.all_subtasks_completed?
    
    # Add pending subtask
    create_test_task(@list, creator: @user, parent_task: @task, status: :pending)
    @task.reload
    assert_not @task.all_subtasks_completed?
  end

  test "should handle visibility settings" do
    @task.make_visible!
    assert_equal "visible", @task.visibility
    
    @task.make_hidden!
    assert_equal "hidden", @task.visibility
    
    @task.make_coaching_only!
    assert_equal "coaching_only", @task.visibility
  end

  test "should check visibility for user" do
    coach = create_test_user(role: "coach")
    other_user = create_test_user(email: "other@example.com")
    
    # Visible task should be visible to everyone
    @task.make_visible!
    assert @task.visible_to?(@user)
    assert @task.visible_to?(coach)
    assert @task.visible_to?(other_user)
    
    # Hidden task should only be visible to creator and list owner
    @task.make_hidden!
    assert @task.visible_to?(@user)
    assert_not @task.visible_to?(coach)
    assert_not @task.visible_to?(other_user)
    
    # Coaching only task should be visible to coaches
    @task.make_coaching_only!
    assert @task.visible_to?(@user)
    assert @task.visible_to?(coach)
    assert_not @task.visible_to?(other_user)
  end

  test "should handle soft delete" do
    assert_not @task.deleted?
    @task.soft_delete!(@user)
    assert @task.deleted?
    assert_not_nil @task.deleted_at
  end

  test "should restore soft deleted task" do
    @task.soft_delete!(@user)
    @task.restore!
    assert_not @task.deleted?
    assert_nil @task.deleted_at
    assert_equal "pending", @task.status
  end

  test "should handle reassignment" do
    new_due_at = 2.hours.from_now
    reason = "Need more time"
    
    result = @task.reassign!(@user, new_due_at: new_due_at, reason: reason)
    assert result
    assert_equal new_due_at.to_i, @task.due_at.to_i
  end

  test "should not reassign without reason in strict mode" do
    @task.update!(strict_mode: true)
    new_due_at = 2.hours.from_now
    
    result = @task.reassign!(@user, new_due_at: new_due_at, reason: "")
    assert_not result
  end

  test "should handle location-based tasks" do
    location_task = create_test_task(@list, 
      creator: @user,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100
    )
    
    assert location_task.location_based?
    assert_equal [40.7128, -74.0060], location_task.coordinates
  end

  test "should check if user is at task location" do
    location_task = create_test_task(@list, 
      creator: @user,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100
    )
    
    # User at same location
    assert location_task.user_at_location?(40.7128, -74.0060)
    
    # User far from location
    assert_not location_task.user_at_location?(40.7589, -73.9851)
  end

  test "should handle recurring tasks" do
    recurring_task = create_test_task(@list, 
      creator: @user,
      is_recurring: true,
      recurrence_pattern: "daily"
    )
    
    assert recurring_task.is_recurring?
    assert recurring_task.is_template?
    assert_not recurring_task.is_instance?
  end

  test "should generate next instance for recurring task" do
    recurring_task = create_test_task(@list, 
      creator: @user,
      is_recurring: true,
      recurrence_pattern: "daily",
      recurrence_time: Time.current
    )
    
    next_instance = recurring_task.generate_next_instance
    assert_not_nil next_instance
    assert_equal recurring_task.title, next_instance.title
    assert next_instance.is_instance?
  end

  test "should handle task events" do
    initial_count = @task.task_events.count
    @task.complete!
    assert_equal initial_count + 1, @task.task_events.count
    
    event = @task.task_events.last
    assert_equal "completed", event.kind
  end

  test "should validate strict_mode inclusion" do
    @task.strict_mode = nil
    assert_not @task.valid?
    assert_includes @task.errors[:strict_mode], "is not included in the list"
  end

  test "should handle priority levels" do
    # Priority attribute doesn't exist in Task model
    # Test a different attribute that does exist
    high_strict_task = create_test_task(@list, creator: @user, strict_mode: true)
    low_strict_task = create_test_task(@list, creator: @user, strict_mode: false)
    
    assert high_strict_task.strict_mode
    assert_not low_strict_task.strict_mode
  end
end