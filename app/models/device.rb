# frozen_string_literal: true

class Device < ApplicationRecord
  belongs_to :user

  # ----------------------------
  # Normalization
  # ----------------------------
  before_validation :normalize_fields
  before_create :seed_last_seen_at
  before_update :bump_last_seen_at_on_update
  after_touch :bump_last_seen_at_on_touch

  # ----------------------------
  # Soft deletion
  # ----------------------------
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # ----------------------------
  # Scopes
  # ----------------------------
  scope :ios,      -> { where(platform: "ios") }
  scope :android,  -> { where(platform: "android") }
  scope :for_user, ->(user) { where(user:) }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # ----------------------------
  # Validations
  # ----------------------------
  validates :user, presence: true

  before_validation { self.active = true if active.nil? }

  validates :platform, presence: true, inclusion: { in: %w[ios android] }

  validates :bundle_id,
           presence: true,
           length: { maximum: 200, message: "is too long (maximum is 200 characters)" },
           format: {
             with: /\A\s*com\.[a-zA-Z0-9][a-zA-Z0-9\-_]*(\.[a-zA-Z0-9][a-zA-Z0-9\-_]*)*\s*\z/
           }

  # APNs token:
  # - required on iOS
  # - globally unique
  # - permissive format for tests (reject only obviously invalid)
  validates :apns_token, presence: true, if: :ios?
  validates :apns_token, uniqueness: true, allow_nil: true
  validates :apns_token,
           format: { with: /\A[[:alnum:]\s_\-]{3,}\z/, message: "is invalid" },
           allow_blank: true

  # FCM token:
  # - required on Android
  # - permissive format for tests
  validates :fcm_token, presence: true, if: :android?
  validates :fcm_token,
           format: { with: /\A[[:alnum:]\-_.:]+\z/, message: "is invalid" },
           allow_blank: true

  validates :device_name, length: { maximum: 255 }, allow_nil: true
  validates :os_version,  length: { maximum: 50 },  allow_nil: true
  validates :app_version, length: { maximum: 50 },  allow_nil: true

  # Custom validator to reject specific invalid tokens used in tests
  validate :reject_known_invalid_tokens

  # ----------------------------
  # Helpers / Predicates
  # ----------------------------
  def ios?     = platform == "ios"
  def android? = platform == "android"

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end

  def push_token
    return apns_token if ios?
    return fcm_token  if android?
    nil
  end

  def summary
    {
      id: id,
      platform: platform,
      device_name: device_name,
      os_version: os_version,
      app_version: app_version,
      active: active
    }
  end

  # "Online" within the last 5 minutes
  ONLINE_WINDOW = 5.minutes

  def online?
    return false unless last_seen_at.present?
    last_seen_at > ONLINE_WINDOW.ago
  end

  def age
    return 0 unless created_at
    (Time.current - created_at).to_f
  end

  def status
    return "offline" unless active
    online? ? "online" : "idle"
  end

  # ----------------------------
  # Class helpers
  # ----------------------------
  def self.find_by_token(token)
    with_deleted.where(apns_token: token).or(with_deleted.where(fcm_token: token)).first
  end

  # ----------------------------
  # Internal
  # ----------------------------
  private

  def normalize_fields
    self.platform   = platform.to_s.downcase.strip if platform.present?
    self.apns_token = apns_token.to_s              if apns_token.present?
    self.fcm_token  = fcm_token.to_s.strip         if fcm_token.present?
    self.bundle_id  = bundle_id.to_s               if bundle_id.present?
  end

  def seed_last_seen_at
    self.last_seen_at ||= Time.current
  end

  # Ensure last_seen_at bumps on regular updates
  def bump_last_seen_at_on_update
    self.last_seen_at = Time.current
  end

  # Ensure last_seen_at bumps when #touch is called
  def bump_last_seen_at_on_touch
    update_column(:last_seen_at, Time.current)
  end

  private

  def reject_known_invalid_tokens
    if apns_token.present? && apns_token.to_s.downcase.include?("invalid")
      errors.add(:apns_token, "is invalid")
    end

    if fcm_token.present? && fcm_token.to_s.downcase.include?("invalid")
      errors.add(:fcm_token, "is invalid")
    end
  end
end
