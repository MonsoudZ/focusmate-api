class Device < ApplicationRecord
  belongs_to :user
  
  validates :apns_token, presence: true, uniqueness: true
  validates :platform, inclusion: { in: %w[ios android] }
  
  # Scopes
  scope :ios, -> { where(platform: 'ios') }
  scope :android, -> { where(platform: 'android') }
  scope :for_user, ->(user) { where(user: user) }
  
  # Check if device is iOS
  def ios?
    platform == 'ios'
  end
  
  # Check if device is Android
  def android?
    platform == 'android'
  end
  
  # Get device summary for display
  def summary
    {
      id: id,
      platform: platform,
      bundle_id: bundle_id,
      created_at: created_at
    }
  end
  
  # Get formatted device name
  def display_name
    "#{platform.capitalize} Device"
  end
end
