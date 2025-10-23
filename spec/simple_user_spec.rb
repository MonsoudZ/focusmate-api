require "rails_helper"

RSpec.describe "Simple User", type: :model do
  it "should create user with valid attributes" do
    user = User.new(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    expect(user).to be_valid
    expect(user.save).to be_truthy
    expect(user.email).to eq(user.email)
    expect(user.role).to eq("client")
  end

  it "should not create user with invalid email" do
    user = User.new(
      email: "invalid-email",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    expect(user).not_to be_valid
    expect(user.errors[:email]).to include("is invalid")
  end

  it "should not create user without password" do
    user = User.new(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      role: "client"
    )
    expect(user).not_to be_valid
    expect(user.errors[:password]).to include("can't be blank")
  end

  it "should encrypt password" do
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client"
    )
    expect(user.encrypted_password).not_to be_nil
    expect(user.encrypted_password).not_to eq("password123")
    expect(user.valid_password?("password123")).to be_truthy
  end
end
