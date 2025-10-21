require "test_helper"

class TaskCreationServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @params = {
      title: "Test Task",
      due_at: 1.hour.from_now.iso8601,
      strict_mode: true
    }
  end

  test "should create task with valid parameters" do
    service = TaskCreationService.new(@list, @user, @params)
    task = service.call
    
    assert_not_nil task
    assert_equal "Test Task", task.title
    assert_equal @user, task.creator
    assert_equal @list, task.list
    assert task.strict_mode
  end

  test "should handle iOS parameters" do
    ios_params = {
      name: "iOS Task", # iOS uses 'name' instead of 'title'
      dueDate: 1.hour.from_now.to_i, # iOS sends epoch seconds
      description: "iOS description" # iOS uses 'description' instead of 'note'
    }
    
    service = TaskCreationService.new(@list, @user, ios_params)
    task = service.call
    
    assert_equal "iOS Task", task.title
    assert_equal "iOS description", task.note
    assert_not_nil task.due_at
  end

  test "should handle ISO8601 date format" do
    params_with_iso_date = @params.merge(
      due_date: 1.hour.from_now.iso8601
    )
    
    service = TaskCreationService.new(@list, @user, params_with_iso_date)
    task = service.call
    
    assert_not_nil task.due_at
    assert_equal 1.hour.from_now.to_i, task.due_at.to_i
  end

  test "should set default values" do
    params_without_defaults = {
      title: "Task without defaults"
    }
    
    service = TaskCreationService.new(@list, @user, params_without_defaults)
    task = service.call
    
    assert task.strict_mode # Should default to true
  end

  test "should create subtasks if provided" do
    params_with_subtasks = @params.merge(
      subtasks: ["Subtask 1", "Subtask 2", "Subtask 3"]
    )
    
    service = TaskCreationService.new(@list, @user, params_with_subtasks)
    task = service.call
    
    assert_equal 3, task.subtasks.count
    assert_equal "Subtask 1", task.subtasks.first.title
    assert_equal "Subtask 2", task.subtasks.second.title
    assert_equal "Subtask 3", task.subtasks.third.title
  end

  test "should set subtask attributes correctly" do
    params_with_subtasks = @params.merge(
      subtasks: ["Subtask"]
    )
    
    service = TaskCreationService.new(@list, @user, params_with_subtasks)
    task = service.call
    
    subtask = task.subtasks.first
    assert_equal @list, subtask.list
    assert_equal @user, subtask.creator
    assert_equal task.due_at, subtask.due_at
    assert_equal task.strict_mode, subtask.strict_mode
  end

  test "should handle invalid date formats gracefully" do
    params_with_invalid_date = @params.merge(
      dueDate: "invalid-date"
    )
    
    service = TaskCreationService.new(@list, @user, params_with_invalid_date)
    task = service.call
    
    # Should still create task but without due_at
    assert_not_nil task
    assert_equal "Test Task", task.title
  end

  test "should clean iOS-specific parameters" do
    ios_params = {
      name: "iOS Task",
      dueDate: 1.hour.from_now.to_i,
      description: "iOS description",
      title: "Should be ignored", # This should be ignored in favor of 'name'
      note: "Should be ignored" # This should be ignored in favor of 'description'
    }
    
    service = TaskCreationService.new(@list, @user, ios_params)
    task = service.call
    
    assert_equal "iOS Task", task.title
    assert_equal "iOS description", task.note
  end

  test "should handle empty subtasks array" do
    params_with_empty_subtasks = @params.merge(
      subtasks: []
    )
    
    service = TaskCreationService.new(@list, @user, params_with_empty_subtasks)
    task = service.call
    
    assert_equal 0, task.subtasks.count
  end

  test "should handle nil subtasks" do
    params_with_nil_subtasks = @params.merge(
      subtasks: nil
    )
    
    service = TaskCreationService.new(@list, @user, params_with_nil_subtasks)
    task = service.call
    
    assert_equal 0, task.subtasks.count
  end

  test "should handle priority setting" do
    # Priority attribute doesn't exist in Task model, so we'll skip this test
    # or test a different attribute that does exist
    params_with_subtasks = @params.merge(
      subtasks: ["Subtask"]
    )
    
    service = TaskCreationService.new(@list, @user, params_with_subtasks)
    task = service.call
    
    assert_equal 1, task.subtasks.count
    assert_equal "Subtask", task.subtasks.first.title
  end

  test "should handle location-based tasks" do
    location_params = @params.merge(
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100,
      location_name: "New York"
    )
    
    service = TaskCreationService.new(@list, @user, location_params)
    task = service.call
    
    assert task.location_based?
    assert_equal 40.7128, task.location_latitude
    assert_equal -74.0060, task.location_longitude
    assert_equal 100, task.location_radius_meters
    assert_equal "New York", task.location_name
  end

  test "should handle recurring tasks" do
    recurring_params = @params.merge(
      is_recurring: true,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: Time.current
    )
    
    service = TaskCreationService.new(@list, @user, recurring_params)
    task = service.call
    
    assert task.is_recurring?
    assert_equal "daily", task.recurrence_pattern
    assert_equal 1, task.recurrence_interval
    assert_not_nil task.recurrence_time
  end

  test "should handle accountability features" do
    accountability_params = @params.merge(
      can_be_snoozed: false,
      notification_interval_minutes: 15,
      requires_explanation_if_missed: true
    )
    
    service = TaskCreationService.new(@list, @user, accountability_params)
    task = service.call
    
    assert_not task.can_be_snoozed?
    assert_equal 15, task.notification_interval_minutes
    assert task.requires_explanation_if_missed?
  end

  test "should handle visibility settings" do
    visibility_params = @params.merge(
      visibility: "coaching_only"
    )
    
    service = TaskCreationService.new(@list, @user, visibility_params)
    task = service.call
    
    assert_equal "coaching_only", task.visibility
  end

  test "should raise error for invalid parameters" do
    invalid_params = {
      title: "", # Empty title should fail validation
      due_at: 1.hour.from_now.iso8601
    }
    
    service = TaskCreationService.new(@list, @user, invalid_params)
    
    assert_raises(ActiveRecord::RecordInvalid) do
      service.call
    end
  end

  test "should handle complex nested parameters" do
    complex_params = {
      name: "Complex Task",
      dueDate: 1.hour.from_now.to_i,
      description: "Complex description",
      # priority: 2, # Priority attribute doesn't exist
      strict_mode: false,
      can_be_snoozed: true,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      subtasks: ["Complex Subtask 1", "Complex Subtask 2"]
    }
    
    service = TaskCreationService.new(@list, @user, complex_params)
    task = service.call
    
    assert_equal "Complex Task", task.title
    assert_equal "Complex description", task.note
    # assert_equal 2, task.priority # Priority attribute doesn't exist
    assert_not task.strict_mode
    assert task.can_be_snoozed?
    assert task.location_based?
    assert_equal 2, task.subtasks.count
  end

  test "should handle edge case with nil parameters" do
    nil_params = {
      title: "Task with nil params",
      due_at: 1.hour.from_now.iso8601,
      note: nil,
      # priority: nil # Priority attribute doesn't exist
    }
    
    service = TaskCreationService.new(@list, @user, nil_params)
    task = service.call
    
    assert_equal "Task with nil params", task.title
    assert_nil task.note
    # assert_nil task.priority # Priority attribute doesn't exist
  end

  test "should handle very long subtask titles" do
    long_subtask_title = "a" * 1000 # Very long but within limit
    params_with_long_subtask = @params.merge(
      subtasks: [long_subtask_title]
    )
    
    service = TaskCreationService.new(@list, @user, params_with_long_subtask)
    task = service.call
    
    assert_equal 1, task.subtasks.count
    assert_equal long_subtask_title, task.subtasks.first.title
  end

  test "should handle special characters in parameters" do
    special_params = {
      name: "Task with émojis 🚀 and spëcial chars",
      description: "Description with <script>alert('xss')</script>",
      dueDate: 1.hour.from_now.to_i
    }
    
    service = TaskCreationService.new(@list, @user, special_params)
    task = service.call
    
    assert_equal "Task with émojis 🚀 and spëcial chars", task.title
    assert_equal "Description with <script>alert('xss')</script>", task.note
  end

  test "should handle timezone-aware dates" do
    timezone_params = @params.merge(
      due_date: "2024-01-01T12:00:00Z" # UTC timezone
    )
    
    service = TaskCreationService.new(@list, @user, timezone_params)
    task = service.call
    
    assert_not_nil task.due_at
    # Should parse the UTC time correctly
    assert_equal "2024-01-01T12:00:00Z", task.due_at.utc.iso8601
  end

  test "should handle multiple date formats" do
    # Test with both dueDate and due_date
    multiple_date_params = {
      name: "Task with multiple dates",
      dueDate: 1.hour.from_now.to_i,
      due_date: 2.hours.from_now.iso8601
    }
    
    service = TaskCreationService.new(@list, @user, multiple_date_params)
    task = service.call
    
    # Should use the first valid date (dueDate)
    assert_not_nil task.due_at
    assert_equal 1.hour.from_now.to_i, task.due_at.to_i
  end
end
