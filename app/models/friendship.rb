class Friendship < ApplicationRecord
  belongs_to :user
  belongs_to :friend, class_name: "User"

  validates :user_id, uniqueness: { scope: :friend_id, message: "is already friends with this user" }
  validate :cannot_friend_self

  # Create mutual friendship (both directions)
  def self.create_mutual!(user_a, user_b)
    transaction do
      create!(user: user_a, friend: user_b)
      create!(user: user_b, friend: user_a)
    end
  end

  # Idempotent mutual friendship creation for race-prone flows.
  # If the friendship already exists in either direction, keep going.
  def self.ensure_mutual!(user_a, user_b)
    transaction do
      ensure_directional_friendship!(user: user_a, friend: user_b)
      ensure_directional_friendship!(user: user_b, friend: user_a)
    end
  end

  # Remove mutual friendship
  def self.destroy_mutual!(user_a, user_b)
    transaction do
      find_by(user: user_a, friend: user_b)&.destroy!
      find_by(user: user_b, friend: user_a)&.destroy!
    end
  end

  # Check if two users are friends
  def self.friends?(user_a, user_b)
    exists?(user: user_a, friend: user_b)
  end

  def self.ensure_directional_friendship!(user:, friend:)
    create!(user: user, friend: friend)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    raise unless exists?(user: user, friend: friend)
  end
  private_class_method :ensure_directional_friendship!

  private

  def cannot_friend_self
    errors.add(:friend, "can't be yourself") if user_id == friend_id
  end
end
