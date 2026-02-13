# frozen_string_literal: true

class Device < ApplicationRecord
  include SoftDeletable
  belongs_to :user

  before_validation :normalize_fields
  before_create :seed_last_seen_at

  # Scopes
  scope :ios, -> { where(platform: "ios") }
  scope :android, -> { where(platform: "android") }
  scope :for_user, ->(user) { where(user: user) }
  scope :active, -> { where(active: true) }

  # Validations
  validates :user, presence: true
  validates :platform, presence: true, inclusion: { in: %w[ios android] }
  validates :bundle_id, presence: true, length: { maximum: 200 }
  validates :apns_token, presence: true, if: :ios?
  validates :apns_token, uniqueness: true, allow_nil: true
  validates :fcm_token, presence: true, if: :android?
  validates :fcm_token, uniqueness: { scope: :user_id }, allow_nil: true
  validates :device_name, length: { maximum: 255 }, allow_nil: true
  validates :os_version, length: { maximum: 50 }, allow_nil: true
  validates :app_version, length: { maximum: 50 }, allow_nil: true

  before_validation { self.active = true if active.nil? }

  def ios?
    platform == "ios"
  end

  def android?
    platform == "android"
  end

  def push_token
    ios? ? apns_token : fcm_token
  end

  private

  def normalize_fields
    self.platform = platform.to_s.downcase.strip if platform.present?
    self.apns_token = apns_token.to_s if apns_token.present?
    self.fcm_token = fcm_token.to_s.strip if fcm_token.present?
    self.bundle_id = bundle_id.to_s if bundle_id.present?
  end

  def seed_last_seen_at
    self.last_seen_at ||= Time.current
  end
end
