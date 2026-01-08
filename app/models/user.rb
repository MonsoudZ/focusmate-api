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

  # Associations
  has_many :owned_lists, class_name: "List", foreign_key: "user_id", dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships, source: :list
  has_many :devices, dependent: :destroy
  has_many :created_tasks, class_name: "Task", foreign_key: "creator_id", dependent: :destroy
  has_many :tags, dependent: :destroy

  def coach?
    role == "coach"
  end

  def client?
    role == "client"
  end

  def push_devices
    devices.where.not(apns_token: nil)
  end

  private

  def valid_timezone
    return if timezone.blank?

    begin
      Time.zone = timezone
    rescue ArgumentError
      errors.add(:timezone, "is not a valid timezone")
    end
  end

  def set_default_role
    self.role = "client" if role.blank?
  end
end
