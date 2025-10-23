require "rails_helper"

RSpec.describe "Working", type: :model do
  it "should parse JSON correctly" do
    # Test that JSON parsing works correctly
    json_string = '{"test": "value"}'
    parsed = JSON.parse(json_string)
    expect(parsed["test"]).to eq("value")
  end

  it "should have correct list owner association" do
    # Test that List model has correct association
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    
    list = List.create!(
      name: "Test List",
      description: "A test list",
      owner: user
    )
    
    expect(list.owner).to eq(user)
    expect(list.user_id == user.id ? user : nil).to eq(user)
  end

  it "should create tasks with correct associations" do
    # Test that task creation works with correct associations
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
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
      status: :pending,
      strict_mode: true
    )
    
    expect(task.creator).to eq(user)
    expect(task.list).to eq(list)
    expect(task.title).to eq("Test Task")
  end

  it "should instantiate authentication controller" do
    # Test that authentication controller can be instantiated
    controller = Api::V1::AuthenticationController.new
    expect(controller).not_to be_nil
  end

  it "should instantiate tasks controller" do
    # Test that tasks controller can be instantiated
    controller = Api::V1::TasksController.new
    expect(controller).not_to be_nil
  end
end
