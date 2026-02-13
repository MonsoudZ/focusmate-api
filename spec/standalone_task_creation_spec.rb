require "rails_helper"

RSpec.describe "Standalone Task Creation", type: :model do
  it "should work with task creation service without priority" do
    # Create test data without fixtures
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )

    list = List.create!(
      name: "Test List",
      description: "A test list",
      user: user
    )

    # Test TaskCreationService with valid parameters (no priority)
    params = {
      title: "Test Task",
      due_at: 1.hour.from_now,
      strict_mode: true
    }

    service = TaskCreationService.new(list: list, user: user, params: params)
    task = service.call!

    expect(task.title).to eq("Test Task")
    expect(task.creator).to eq(user)
    expect(task.list).to eq(list)
    expect(task.strict_mode).to be_truthy
  end

  it "should handle subtasks in task creation service" do
    # Create test data
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )

    list = List.create!(
      name: "Test List",
      description: "A test list",
      user: user
    )

    # Test with subtasks
    params = {
      title: "Parent Task",
      due_at: 1.hour.from_now,
      strict_mode: true,
      subtasks: [ "Subtask 1", "Subtask 2" ]
    }

    service = TaskCreationService.new(list: list, user: user, params: params)
    task = service.call!

    expect(task.title).to eq("Parent Task")
    expect(task.subtasks.count).to eq(2)
    expect(task.subtasks.first.title).to eq("Subtask 1")
    expect(task.subtasks.second.title).to eq("Subtask 2")
  end

  it "should handle iOS parameters in task creation service" do
    # Create test data
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )

    list = List.create!(
      name: "Test List",
      description: "A test list",
      user: user
    )

    # Test with iOS-specific parameters
    params = {
      name: "iOS Task",  # iOS uses 'name' instead of 'title'
      dueDate: 1.hour.from_now.to_i,  # iOS uses 'dueDate' with timestamp
      description: "iOS description",  # iOS uses 'description' instead of 'note'
      strict_mode: false
    }

    service = TaskCreationService.new(list: list, user: user, params: params)
    task = service.call!

    expect(task.title).to eq("iOS Task")
    expect(task.note).to eq("iOS description")
    expect(task.strict_mode).to be_falsy
  end

  it "should create device with correct attributes" do
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )

    # Test device creation with correct attributes
    device = user.devices.create!(
      platform: "ios",
      apns_token: "test_token_#{SecureRandom.hex(8)}",
      bundle_id: "com.intentia.app"
    )

    expect(device.platform).to eq("ios")
    expect(device.bundle_id).to eq("com.intentia.app")
    expect(user.devices).to include(device)
  end
end
