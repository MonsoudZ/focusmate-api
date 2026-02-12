# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  before_create :set_default_role

  # Validations
  validates :timezone, presence: true
  validates :role, presence: true, inclusion: { in: %w[client coach] }
  validate :valid_timezone
  validates :name, presence: true
  before_validation :set_default_name

  # Associations
  has_many :owned_lists, class_name: "List", foreign_key: "user_id", dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships, source: :list
  has_many :devices, dependent: :destroy
  has_many :created_tasks, class_name: "Task", foreign_key: "creator_id", dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :refresh_tokens, dependent: :delete_all
  has_many :friendships, dependent: :destroy
  has_many :friends, through: :friendships, source: :friend

  def coach?
    role == "coach"
  end

  def client?
    role == "client"
  end

  private

  def set_default_name
    self.name = "User" if name.blank?
  end

  def valid_timezone
    return if timezone.blank?

    unless ActiveSupport::TimeZone[timezone]
      errors.add(:timezone, "is not a valid timezone")
    end
  end

  def set_default_role
    self.role = "client" if role.blank?
  end
end
