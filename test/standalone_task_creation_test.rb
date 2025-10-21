require 'minitest/autorun'
require_relative '../config/environment'

class StandaloneTaskCreationTest < Minitest::Test
  def test_task_creation_service_works_without_priority
    # Create test data without fixtures
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    
    list = List.create!(
      name: "Test List",
      description: "A test list",
      owner: user
    )
    
    # Test TaskCreationService with valid parameters (no priority)
    params = {
      title: "Test Task",
      due_at: 1.hour.from_now,
      strict_mode: true
    }
    
    service = TaskCreationService.new(list, user, params)
    task = service.call
    
    assert_equal "Test Task", task.title
    assert_equal user, task.creator
    assert_equal list, task.list
    assert task.strict_mode
  end

  def test_task_creation_service_handles_subtasks
    # Create test data
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    
    list = List.create!(
      name: "Test List",
      description: "A test list",
      owner: user
    )
    
    # Test with subtasks
    params = {
      title: "Parent Task",
      due_at: 1.hour.from_now,
      strict_mode: true,
      subtasks: ["Subtask 1", "Subtask 2"]
    }
    
    service = TaskCreationService.new(list, user, params)
    task = service.call
    
    assert_equal "Parent Task", task.title
    assert_equal 2, task.subtasks.count
    assert_equal "Subtask 1", task.subtasks.first.title
    assert_equal "Subtask 2", task.subtasks.second.title
  end

  def test_task_creation_service_handles_ios_parameters
    # Create test data
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    
    list = List.create!(
      name: "Test List",
      description: "A test list",
      owner: user
    )
    
    # Test with iOS-specific parameters
    params = {
      name: "iOS Task",  # iOS uses 'name' instead of 'title'
      dueDate: 1.hour.from_now.to_i,  # iOS uses 'dueDate' with timestamp
      description: "iOS description",  # iOS uses 'description' instead of 'note'
      strict_mode: false
    }
    
    service = TaskCreationService.new(list, user, params)
    task = service.call
    
    assert_equal "iOS Task", task.title
    assert_equal "iOS description", task.note
    refute task.strict_mode
  end

  def test_device_creation_works_with_correct_attributes
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    
    # Test device creation with correct attributes
    device = user.devices.create!(
      platform: "ios",
      apns_token: "test_token_#{SecureRandom.hex(8)}",
      bundle_id: "com.focusmate.app"
    )
    
    assert_equal "ios", device.platform
    assert_equal "com.focusmate.app", device.bundle_id
    assert_includes user.devices, device
  end
end
