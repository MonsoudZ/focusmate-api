# frozen_string_literal: true

class DeviceManagementService
  def initialize(user:)
    @user = user
  end

  def register(token:, platform:, locale: nil, app_version: nil, device_name: nil, os_version: nil, bundle_id: nil, fcm_token: nil, apns_token: nil)
    Device.transaction do
      # Normalize platform and default to ios if empty
      platform = platform.to_s.downcase.strip
      platform = "ios" if platform.blank?

      # Find existing device by any token (APNs or FCM)
      device = Device.find_by(user: @user, apns_token: token) ||
               Device.find_by(user: @user, fcm_token: token)

      # Create new device if not found
      device ||= Device.new(user: @user)

      # Set platform-specific attributes
      if platform == "ios"
        device.apns_token = token
        device.fcm_token = fcm_token if fcm_token.present?
        device.bundle_id = bundle_id.present? ? bundle_id : "com.example.app"
      else
        device.fcm_token = token
        # For Android, also set APNs token if provided
        device.apns_token = apns_token if apns_token.present?
        device.bundle_id = bundle_id.present? ? bundle_id : "com.example.app"
      end

      # Set common attributes
      device.platform = platform
      device.app_version = app_version
      device.device_name = device_name
      device.os_version = os_version
      device.last_seen_at = Time.current

      device.save!
      device
    end
  end

  def touch!(token:, platform:)
    token_field = platform == "ios" ? :apns_token : :fcm_token
    Device.where(user: @user, token_field => token).update_all(last_seen_at: Time.current)
  end

  def revoke(token:, platform:)
    token_field = platform == "ios" ? :apns_token : :fcm_token
    Device.where(user: @user, token_field => token).delete_all
  end

  def find_by_token(token:, platform:)
    token_field = platform == "ios" ? :apns_token : :fcm_token
    Device.where(user: @user, token_field => token).first
  end

  def list
    @user.devices.includes(:user)
  end

  def update_device(device:, attributes:)
    device.update!(attributes.merge(last_seen_at: Time.current))
    device
  end

  def send_test_push(device:)
    begin
      NotificationService.send_test_notification(
        @user,
        "Test Push: This is a test push notification from the API"
      )
      {
        success: true,
        message: "Test push notification sent successfully",
        device_id: device.id,
        platform: device.platform
      }
    rescue => e
      {
        success: false,
        error: "Failed to send test push: #{e.message}"
      }
    end
  end
end
