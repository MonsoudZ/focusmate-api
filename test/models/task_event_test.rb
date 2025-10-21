require "test_helper"

class TaskEventTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @task = create_test_task(@list, creator: @user)
    @task_event = TaskEvent.new(
      task: @task,
      user: @user,
      kind: "created",
      reason: "Task was created",
      occurred_at: Time.current
    )
  end

  test "should belong to task" do
    assert @task_event.valid?
    assert_equal @task, @task_event.task
  end

  test "should belong to user" do
    assert @task_event.valid?
    assert_equal @user, @task_event.user
  end

  test "should require kind" do
    @task_event.kind = nil
    assert_not @task_event.valid?
    assert_includes @task_event.errors[:kind], "can't be blank"
  end

  test "should validate kind enum values" do
    # Test valid enum values
    valid_kinds = %w[created updated completed reassigned deleted]
    
    valid_kinds.each do |kind|
      @task_event.kind = kind
      assert @task_event.valid?, "Kind '#{kind}' should be valid"
    end

    # Test invalid enum values - these will raise ArgumentError, not validation errors
    assert_raises(ArgumentError) do
      @task_event.kind = "invalid"
    end

    assert_raises(ArgumentError) do
      @task_event.kind = "cancelled"
    end
  end

  test "should record reason for reassignments" do
    @task_event.kind = "reassigned"
    @task_event.reason = "Task was reassigned to different user"
    
    assert @task_event.valid?
    assert_equal "Task was reassigned to different user", @task_event.reason
  end

  test "should allow reason for other event types" do
    @task_event.kind = "completed"
    @task_event.reason = "Task was completed successfully"
    
    assert @task_event.valid?
    assert_equal "Task was completed successfully", @task_event.reason
  end

  test "should allow nil reason" do
    @task_event.reason = nil
    assert @task_event.valid?
  end

  test "should allow empty reason" do
    @task_event.reason = ""
    assert @task_event.valid?
  end

  test "should validate reason length" do
    @task_event.reason = "a" * 501
    assert_not @task_event.valid?
    assert_includes @task_event.errors[:reason], "is too long (maximum is 500 characters)"

    @task_event.reason = "a" * 500
    assert @task_event.valid?
  end

  test "should default occurred_at to now" do
    # Create event without setting occurred_at
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created"
    )
    
    # Should be set to current time (within a few seconds)
    assert_not_nil event.occurred_at
    assert event.occurred_at <= Time.current
    assert event.occurred_at >= 1.second.ago
  end

  test "should order events by occurred_at descending" do
    # Clear any existing events first
    @task.task_events.destroy_all
    
    # Create events with different occurred_at times
    event1 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: 3.hours.ago
    )
    
    event2 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      occurred_at: 2.hours.ago
    )
    
    event3 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "completed",
      occurred_at: 1.hour.ago
    )
    
    recent_events = TaskEvent.recent
    assert_equal event3, recent_events.first
    assert_equal event2, recent_events.second
    assert_equal event1, recent_events.third
  end

  test "should track who made the change" do
    other_user = create_test_user
    
    @task_event.user = other_user
    @task_event.save!
    
    assert_equal other_user, @task_event.user
    assert_equal other_user.id, @task_event.user_id
  end

  test "should use by_kind scope" do
    created_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created"
    )
    
    updated_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated"
    )
    
    completed_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "completed"
    )
    
    created_events = TaskEvent.by_kind("created")
    assert_includes created_events, created_event
    assert_not_includes created_events, updated_event
    assert_not_includes created_events, completed_event
  end

  test "should use with_reasons scope" do
    event_with_reason = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: "Task was reassigned"
    )
    
    event_without_reason = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created"
    )
    
    events_with_reasons = TaskEvent.with_reasons
    assert_includes events_with_reasons, event_with_reason
    assert_not_includes events_with_reasons, event_without_reason
  end

  test "should get audit trail for task" do
    # Clear any existing events first
    @task.task_events.destroy_all
    
    event1 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: 3.hours.ago
    )
    
    event2 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      occurred_at: 2.hours.ago
    )
    
    audit_trail = TaskEvent.audit_trail_for(@task)
    assert_includes audit_trail, event1
    assert_includes audit_trail, event2
    assert_equal event2, audit_trail.first # Most recent first
    assert_equal event1, audit_trail.last
  end

  test "should get reassignments for task" do
    reassignment1 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: "First reassignment"
    )
    
    reassignment2 = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: "Second reassignment"
    )
    
    other_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "completed"
    )
    
    reassignments = TaskEvent.reassignments_for(@task)
    assert_includes reassignments, reassignment1
    assert_includes reassignments, reassignment2
    assert_not_includes reassignments, other_event
    assert_equal 2, reassignments.count
  end

  test "should handle all event kinds" do
    kinds = %w[created updated completed reassigned deleted]
    
    kinds.each do |kind|
      event = TaskEvent.create!(
        task: @task,
        user: @user,
        kind: kind,
        reason: "Test #{kind} event"
      )
      
      assert event.valid?
      assert event.persisted?
      assert_equal kind, event.kind
    end
  end

  test "should handle multiple events for same task" do
    # Clear any existing events first
    @task.task_events.destroy_all
    
    # Create multiple events for the same task
    events = []
    
    5.times do |i|
      event = TaskEvent.create!(
        task: @task,
        user: @user,
        kind: "updated",
        reason: "Update #{i + 1}",
        occurred_at: i.hours.ago
      )
      events << event
    end
    
    assert_equal 5, @task.task_events.count
    assert_equal 5, TaskEvent.where(task: @task).count
  end

  test "should handle events from different users" do
    other_user = create_test_user
    
    # Clear any existing events first
    @task.task_events.destroy_all
    
    user1_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created"
    )
    
    user2_event = TaskEvent.create!(
      task: @task,
      user: other_user,
      kind: "updated"
    )
    
    assert_equal @user, user1_event.user
    assert_equal other_user, user2_event.user
    assert_equal 2, @task.task_events.count
  end

  test "should handle events with long reasons" do
    long_reason = "This is a very long reason that explains in detail why this task event occurred. " * 10
    
    # Truncate to 500 characters to stay within limit
    long_reason = long_reason[0, 500]
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: long_reason
    )
    
    assert event.valid?
    assert_equal long_reason, event.reason
  end

  test "should handle events with special characters in reason" do
    special_reason = "Reason with special chars: @#$%^&*()_+-=[]{}|;':\",./<>? and émojis 🎯"
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      reason: special_reason
    )
    
    assert event.valid?
    assert_equal special_reason, event.reason
  end

  test "should handle events with nil occurred_at" do
    event = TaskEvent.new(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: nil
    )
    
    # The callback should set occurred_at automatically
    event.valid?
    assert_not_nil event.occurred_at
    assert event.valid?
  end

  test "should handle events with future occurred_at" do
    future_time = 1.hour.from_now
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: future_time
    )
    
    assert event.valid?
    assert_equal future_time.to_i, event.occurred_at.to_i
  end

  test "should handle events with past occurred_at" do
    past_time = 1.hour.ago
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: past_time
    )
    
    assert event.valid?
    assert_equal past_time.to_i, event.occurred_at.to_i
  end

  test "should handle events with very old occurred_at" do
    very_old_time = 1.year.ago
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: very_old_time
    )
    
    assert event.valid?
    assert_equal very_old_time.to_i, event.occurred_at.to_i
  end

  test "should handle events with very future occurred_at" do
    very_future_time = 1.year.from_now
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: very_future_time
    )
    
    assert event.valid?
    assert_equal very_future_time.to_i, event.occurred_at.to_i
  end

  test "should handle events with different time zones" do
    # Test with different time zones
    utc_time = Time.utc(2024, 1, 1, 12, 0, 0)
    local_time = Time.local(2024, 1, 1, 12, 0, 0)
    
    utc_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: utc_time
    )
    
    local_event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      occurred_at: local_time
    )
    
    assert utc_event.valid?
    assert local_event.valid?
    assert_equal utc_time.to_i, utc_event.occurred_at.to_i
    assert_equal local_time.to_i, local_event.occurred_at.to_i
  end

  test "should handle events with microsecond precision" do
    precise_time = Time.current
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "created",
      occurred_at: precise_time
    )
    
    assert event.valid?
    # Should be within 1 second of the original time
    assert (event.occurred_at - precise_time).abs < 1.second
  end

  test "should handle events with different task statuses" do
    # Create events for tasks with different statuses
    pending_task = create_test_task(@list, creator: @user, status: :pending)
    completed_task = create_test_task(@list, creator: @user, status: :done)
    
    pending_event = TaskEvent.create!(
      task: pending_task,
      user: @user,
      kind: "created"
    )
    
    completed_event = TaskEvent.create!(
      task: completed_task,
      user: @user,
      kind: "completed"
    )
    
    assert pending_event.valid?
    assert completed_event.valid?
    assert_equal "pending", pending_event.task.status
    assert_equal "done", completed_event.task.status
  end

  test "should handle events for deleted tasks" do
    deleted_task = create_test_task(@list, creator: @user, status: :deleted)
    
    event = TaskEvent.create!(
      task: deleted_task,
      user: @user,
      kind: "deleted"
    )
    
    assert event.valid?
    assert_equal "deleted", event.task.status
  end

  test "should handle events with empty string reason" do
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      reason: ""
    )
    
    assert event.valid?
    assert_equal "", event.reason
  end

  test "should handle events with whitespace-only reason" do
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      reason: "   "
    )
    
    assert event.valid?
    assert_equal "   ", event.reason
  end

  test "should handle events with multiline reason" do
    multiline_reason = "This is a multiline reason.\nIt has multiple lines.\nAnd explains the event in detail."
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: multiline_reason
    )
    
    assert event.valid?
    assert_equal multiline_reason, event.reason
  end

  test "should handle events with tab characters in reason" do
    tab_reason = "Reason with\ttab characters\tand spaces"
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      reason: tab_reason
    )
    
    assert event.valid?
    assert_equal tab_reason, event.reason
  end

  test "should handle events with unicode characters in reason" do
    unicode_reason = "Reason with unicode: 中文, العربية, русский, 日本語, 한국어"
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "updated",
      reason: unicode_reason
    )
    
    assert event.valid?
    assert_equal unicode_reason, event.reason
  end

  test "should handle events with maximum length reason" do
    max_reason = "a" * 500
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: max_reason
    )
    
    assert event.valid?
    assert_equal max_reason, event.reason
  end

  test "should handle events with exactly 500 character reason" do
    exact_reason = "a" * 500
    
    event = TaskEvent.create!(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: exact_reason
    )
    
    assert event.valid?
    assert_equal 500, event.reason.length
  end

  test "should handle events with 501 character reason" do
    too_long_reason = "a" * 501
    
    event = TaskEvent.new(
      task: @task,
      user: @user,
      kind: "reassigned",
      reason: too_long_reason
    )
    
    assert_not event.valid?
    assert_includes event.errors[:reason], "is too long (maximum is 500 characters)"
  end
end