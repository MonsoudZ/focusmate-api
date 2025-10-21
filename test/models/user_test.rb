require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Disable fixtures for this test to avoid conflicts
  self.use_transactional_tests = true
  
  def setup
    @user = create_test_user
  end

  test "should create user with valid attributes" do
    user = User.new(
      email: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert user.valid?
    assert user.save
  end

  test "should not create user without email" do
    user = User.new(password: "password123", role: "client")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should not create user with invalid email" do
    user = User.new(email: "invalid-email", password: "password123", role: "client")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "should not create user without password" do
    user = User.new(email: "test@example.com", role: "client")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should not create user with short password" do
    user = User.new(email: "test@example.com", password: "123", role: "client")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should not create user with duplicate email" do
    user1 = create_test_user(email: "duplicate@example.com")
    user2 = User.new(email: "duplicate@example.com", password: "password123", role: "client")
    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  test "should generate JTI on create" do
    user = User.create!(
      email: "jti@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert_not_nil user.jti
    assert user.jti.length > 0
  end

  test "should identify coach role correctly" do
    coach = create_test_user(role: "coach")
    client = create_test_user(role: "client")
    
    assert coach.coach?
    assert_not coach.client?
    assert_not client.coach?
    assert client.client?
  end

  test "should create owned lists" do
    list = create_test_list(@user)
    assert_includes @user.owned_lists, list
    assert_equal @user, list.owner
  end

  test "should create tasks" do
    list = create_test_list(@user)
    task = create_test_task(list, creator: @user)
    assert_includes @user.created_tasks, task
    assert_equal @user, task.creator
  end

  test "should have coaching relationships" do
    coach = create_test_user(role: "coach")
    client = create_test_user(role: "client")
    
    relationship = CoachingRelationship.create!(
      coach: coach,
      client: client,
      invited_by: "coach",
      status: "active"
    )
    
    assert_includes coach.coaching_relationships_as_coach, relationship
    assert_includes client.coaching_relationships_as_client, relationship
  end

  test "should update location" do
    @user.update_location!(40.7128, -74.0060, 10.0)
    location = @user.current_location
    
    assert_not_nil location
    assert_equal 40.7128, location.latitude
    assert_equal -74.0060, location.longitude
    assert_equal 10.0, location.accuracy
  end

  test "should calculate distance to location" do
    # Test location: New York City
    @user.update_location!(40.7128, -74.0060)
    
    # Verify location was recorded
    assert @user.user_locations.exists?
    assert_equal 40.7128, @user.current_location.latitude
    assert_equal -74.0060, @user.current_location.longitude
    
    # Create a saved location for testing
    saved_location = @user.saved_locations.create!(
      name: "Test Location",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 100
    )
    
    # Test if user is at the same location (should be true within 100m)
    assert @user.at_location?(saved_location, 40.7128, -74.0060)
    
    # Test if user is far from location (should be false)
    far_location = @user.saved_locations.create!(
      name: "Far Location",
      latitude: 40.7589,
      longitude: -73.9851,
      radius_meters: 100
    )
    assert_not @user.at_location?(far_location, 40.7128, -74.0060)
  end

  test "should get overdue tasks" do
    list = create_test_list(@user)
    overdue_task = create_test_task(list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending
    )
    future_task = create_test_task(list, 
      creator: @user, 
      due_at: 1.hour.from_now, 
      status: :pending
    )
    
    overdue_tasks = @user.overdue_tasks
    assert_includes overdue_tasks, overdue_task
    assert_not_includes overdue_tasks, future_task
  end

  test "should get tasks requiring explanation" do
    list = create_test_list(@user)
    task = create_test_task(list, 
      creator: @user, 
      due_at: 1.hour.ago, 
      status: :pending,
      requires_explanation_if_missed: true
    )
    
    tasks_requiring_explanation = @user.tasks_requiring_explanation
    assert_includes tasks_requiring_explanation, task
  end

  test "should handle device management" do
    device = @user.devices.create!(
      platform: "ios",
      apns_token: "test_token_123",
      bundle_id: "com.focusmate.app"
    )
    
    assert_includes @user.devices, device
    assert @user.has_devices?
    assert_equal 1, @user.device_count
  end

  test "should handle notification statistics" do
    # Create some notification logs
    @user.notification_logs.create!(
      notification_type: "task_reminder",
      delivered: true,
      metadata: { "read" => false }
    )
    
    stats = @user.notification_stats
    assert_equal 1, stats[:total]
    assert_equal 1, stats[:unread]
    assert_equal 1, stats[:delivered]
  end

  test "should validate role constraints" do
    # Test valid roles
    valid_roles = ["client", "coach"]
    valid_roles.each do |role|
      user = User.new(email: "test@example.com", password: "password123", role: role)
      assert user.valid?, "Role '#{role}' should be valid"
    end
  end

  test "should handle password confirmation" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "different_password",
      role: "client"
    )
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "should encrypt password" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert_not_nil user.encrypted_password
    assert_not_equal "password123", user.encrypted_password
    assert user.valid_password?("password123")
  end
end