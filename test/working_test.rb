require 'minitest/autorun'
require_relative '../config/environment'

class WorkingTest < Minitest::Test
  def test_json_parsing_works
    # Test that JSON parsing works correctly
    json_string = '{"test": "value"}'
    parsed = JSON.parse(json_string)
    assert_equal "value", parsed["test"]
  end

  def test_list_owner_association_works
    # Test that List model has correct association
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
    
    assert_equal user, list.owner
    assert_equal user, list.user_id == user.id ? user : nil
  end

  def test_task_creation_works
    # Test that task creation works with correct associations
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
    
    task = list.tasks.create!(
      title: "Test Task",
      due_at: 1.hour.from_now,
      creator: user,
      strict_mode: true
    )
    
    assert_equal user, task.creator
    assert_equal list, task.list
    assert_equal "Test Task", task.title
  end

  def test_authentication_controller_works
    # Test that authentication controller can be instantiated
    controller = Api::V1::AuthenticationController.new
    assert controller
  end

  def test_tasks_controller_works
    # Test that tasks controller can be instantiated
    controller = Api::V1::TasksController.new
    assert controller
  end
end
