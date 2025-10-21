require 'minitest/autorun'
require_relative '../config/environment'

class NoFixturesTest < Minitest::Test
  def test_should_create_user_with_valid_attributes
    email = "test#{SecureRandom.hex(4)}@example.com"
    user = User.new(
      email: email,
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert user.valid?
    assert user.save
    assert_equal email, user.email
    assert_equal "client", user.role
  end

  def test_should_not_create_user_with_invalid_email
    user = User.new(
      email: "invalid-email",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    refute user.valid?
    assert user.errors[:email].include?("is invalid")
  end

  def test_should_not_create_user_without_password
    user = User.new(
      email: "test#{SecureRandom.hex(4)}@example.com",
      role: "client"
    )
    refute user.valid?
    assert user.errors[:password].include?("can't be blank")
  end

  def test_should_encrypt_password
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    assert user.encrypted_password
    refute_equal "password123", user.encrypted_password
    assert user.valid_password?("password123")
  end
end
