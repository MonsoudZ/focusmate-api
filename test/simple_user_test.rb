require 'test_helper'

class SimpleUserTest < ActiveSupport::TestCase
  # Disable fixtures for this test
  self.use_transactional_tests = true
  
  test "should create user with valid attributes" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert user.valid?
    assert user.save
    assert_equal "test@example.com", user.email
    assert_equal "client", user.role
  end

  test "should not create user with invalid email" do
    user = User.new(
      email: "invalid-email",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "should not create user without password" do
    user = User.new(
      email: "test@example.com",
      role: "client"
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
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
