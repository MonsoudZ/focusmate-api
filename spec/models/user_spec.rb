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

    it 'validates latitude bounds' do
      user = build(:user, latitude: 91)
      expect(user).not_to be_valid
      expect(user.errors[:latitude]).to include("must be less than or equal to 90")
    end

    it 'validates longitude bounds' do
      user = build(:user, longitude: 181)
      expect(user).not_to be_valid
      expect(user.errors[:longitude]).to include("must be less than or equal to 180")
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

    it 'has many saved_locations' do
      expect(user).to respond_to(:saved_locations)
      expect(user.saved_locations).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many user_locations' do
      expect(user).to respond_to(:user_locations)
      expect(user.user_locations).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many coaching_relationships as coach' do
      expect(user).to respond_to(:coaching_relationships_as_coach)
      expect(user.coaching_relationships_as_coach).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it 'has many coaching_relationships as client' do
      expect(user).to respond_to(:coaching_relationships_as_client)
      expect(user.coaching_relationships_as_client).to be_a(ActiveRecord::Associations::CollectionProxy)
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

  describe 'methods' do
    it 'checks if user is coach' do
      coach = create(:user, role: "coach")
      client = create(:user, role: "client")

      expect(coach.coach?).to be true
      expect(client.coach?).to be false
    end

    it 'checks if user is client' do
      coach = create(:user, role: "coach")
      client = create(:user, role: "client")

      expect(client.client?).to be true
      expect(coach.client?).to be false
    end

    it 'returns current location from user_locations' do
      UserLocation.create!(user: user, latitude: 40.7128, longitude: -74.0060, recorded_at: Time.current)
      expect(user.current_location).to be_a(UserLocation)
      expect(user.current_location.latitude).to eq(40.7128)
      expect(user.current_location.longitude).to eq(-74.0060)
    end

    it 'returns nil current location when no user_locations' do
      expect(user.current_location).to be_nil
    end

    it 'checks if user is at specific saved location' do
      saved_location = SavedLocation.create!(user: user, name: "Test Location", latitude: 40.7128, longitude: -74.0060, radius_meters: 100)
      UserLocation.create!(user: user, latitude: 40.7128, longitude: -74.0060, recorded_at: Time.current)
      # Test with explicit coordinates
      expect(user.at_location?(saved_location, 40.7128, -74.0060)).to be true
    end

    it 'returns false when not at saved location' do
      saved_location = SavedLocation.create!(user: user, name: "Test Location", latitude: 40.7128, longitude: -74.0060, radius_meters: 100)
      expect(user.at_location?(saved_location)).to be false
    end
  end

  describe 'callbacks' do
    it 'generates JTI on create' do
      user = build(:user)
      expect(user.jti).to be_nil
      user.save!
      expect(user.jti).not_to be_nil
    end

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

  describe 'role methods' do
    it 'returns correct role methods' do
      coach = create(:user, role: "coach")
      client = create(:user, role: "client")

      expect(coach.coach?).to be true
      expect(coach.client?).to be false
      expect(client.coach?).to be false
      expect(client.client?).to be true
    end
  end

  describe 'coaching relationships' do
    let(:coach) { create(:user, role: "coach") }
    let(:client) { create(:user, role: "client") }

    it 'has coaching relationships as coach' do
      relationship = create(:coaching_relationship, coach: coach, client: client)
      expect(coach.coaching_relationships_as_coach).to include(relationship)
    end

    it 'has coaching relationships as client' do
      relationship = create(:coaching_relationship, coach: coach, client: client)
      expect(client.coaching_relationships_as_client).to include(relationship)
    end

    it 'checks coaching relationship with another user' do
      relationship = create(:coaching_relationship, coach: coach, client: client, status: :active)
      expect(coach.coaching_relationship_with?(client)).to be true
      expect(client.coaching_relationship_with?(coach)).to be true
    end

    it 'gets coaching relationship with another user' do
      relationship = create(:coaching_relationship, coach: coach, client: client, status: :active)
      expect(coach.coaching_relationship_with(client)).to eq(relationship)
      expect(client.coaching_relationship_with(coach)).to eq(relationship)
    end
  end
end
