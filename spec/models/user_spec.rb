# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'creates user with valid attributes' do
      user = build(:user, email: "newuser@example.com", role: "client")
      expect(user).to be_valid
      expect(user.save).to be true
    end

    it 'does not create user without email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'does not create user with invalid email' do
      user = build(:user, email: "invalid-email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it 'does not create user without password' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'does not create user with short password' do
      user = build(:user, password: "123")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
    end

    it 'does not create user with duplicate email' do
      create(:user, email: "duplicate@example.com")
      user2 = build(:user, email: "duplicate@example.com")
      expect(user2).not_to be_valid
      expect(user2.errors[:email]).to include("has already been taken")
    end

    it 'validates email format' do
      user = build(:user, email: "invalid-email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it 'validates password confirmation' do
      user = build(:user, password: "password123", password_confirmation: "different")
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it 'validates role inclusion' do
      user = build(:user, role: "invalid_role")
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("is not included in the list")
    end
  end

  describe 'associations' do
    it 'has many owned_lists' do
      expect(user).to respond_to(:owned_lists)
      expect(user.owned_lists).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many memberships' do
      expect(user).to respond_to(:memberships)
      expect(user.memberships).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many lists through memberships' do
      expect(user).to respond_to(:lists)
      expect(user.lists).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many devices' do
      expect(user).to respond_to(:devices)
      expect(user.devices).to be_a(ActiveRecord::Associations::CollectionProxy)
    end
  end

  describe 'scopes' do
    it 'can filter users by role' do
      coach = create(:user, role: "coach")
      client = create(:user, role: "client")

      coaches = User.where(role: "coach")
      clients = User.where(role: "client")

      expect(coaches).to include(coach)
      expect(coaches).not_to include(client)
      expect(clients).to include(client)
      expect(clients).not_to include(coach)
    end
  end

  describe 'callbacks' do
    it 'validates timezone' do
      user = build(:user, timezone: "Invalid/Timezone")
      expect(user).not_to be_valid
      expect(user.errors[:timezone]).to include("is not a valid timezone")
    end
  end

  describe 'password requirements' do
    it 'requires password on create' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
    end

    it 'does not require password on update if not changed' do
      user.save!
      user.name = "New Name"
      expect(user).to be_valid
    end

    it 'requires password confirmation when password is set' do
      user = build(:user, password: "newpassword", password_confirmation: "different")
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'email normalization' do
    it 'normalizes email to lowercase' do
      user = create(:user, email: "NORMALIZE#{SecureRandom.hex(4)}@EXAMPLE.COM")
      expect(user.email).to eq(user.email.downcase)
    end

    it 'strips whitespace from email' do
      user = create(:user, email: " whitespace#{SecureRandom.hex(4)}@example.com ")
      expect(user.email).to eq(user.email.strip)
    end
  end
end
