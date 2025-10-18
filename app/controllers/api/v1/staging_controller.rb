module Api
  module V1
    class StagingController < ApplicationController
      before_action :authenticate_user!
      before_action :ensure_staging_environment

      # POST /api/v1/staging/test_push
      def test_push
        user = current_user
        
        # Enqueue test push notification job
        TestPushNotificationJob.perform_later(
          user.id,
          params[:title] || "Staging Test Push",
          params[:body] || "This is a test push notification from staging",
          {
            environment: Rails.env.to_s,
            timestamp: Time.current.to_i,
            user_id: user.id
          }
        )
        
        render json: {
          message: "Test push notification job enqueued",
          user_id: user.id,
          device_count: user.devices.count,
          ios_devices: user.ios_devices.count,
          android_devices: user.android_devices.count,
          job_id: "TestPushNotificationJob-#{user.id}"
        }
      end

      # POST /api/v1/staging/test_push_immediate
      def test_push_immediate
        user = current_user
        
        # Send immediate test push (synchronous)
        begin
          # Send test notification to all devices
          NotificationService.send_test_notification(
            user,
            "#{params[:title] || 'Immediate Test Push'}: #{params[:body] || 'This is an immediate test push notification'}"
          )
          
          render json: {
            message: "Immediate test push notification sent",
            user_id: user.id,
            device_count: user.devices.count,
            ios_devices: user.ios_devices.count,
            android_devices: user.android_devices.count
          }
        rescue => e
          render json: {
            error: "Failed to send immediate test push: #{e.message}",
            user_id: user.id,
            device_count: user.devices.count
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/staging/push_status
      def push_status
        user = current_user
        
        render json: {
          user_id: user.id,
          email: user.email,
          device_count: user.devices.count,
          devices: user.devices.map do |device|
            {
              id: device.id,
              platform: device.platform,
              apns_token: device.apns_token.present? ? "#{device.apns_token[0..10]}..." : nil,
              bundle_id: device.bundle_id,
              created_at: device.created_at.iso8601
            }
          end,
          notification_stats: user.notification_stats,
          environment: Rails.env,
          apns_configured: APNS_CLIENT.present?,
          fcm_configured: defined?(FCM) && FCM.present?
        }
      end

      # POST /api/v1/staging/cleanup_test_data
      def cleanup_test_data
        user = current_user
        
        # Clean up test devices and notifications
        test_devices = user.devices.where("apns_token LIKE ?", "test_%")
        test_notifications = user.notification_logs.where("metadata->>'test' = 'true'")
        
        devices_deleted = test_devices.count
        notifications_deleted = test_notifications.count
        
        test_devices.destroy_all
        test_notifications.destroy_all
        
        render json: {
          message: "Test data cleaned up",
          devices_deleted: devices_deleted,
          notifications_deleted: notifications_deleted,
          remaining_devices: user.devices.count,
          remaining_notifications: user.notification_logs.count
        }
      end

      private

      def ensure_staging_environment
        unless Rails.env.staging? || Rails.env.development?
          render json: { error: "This endpoint is only available in staging/development" }, status: :forbidden
        end
      end
    end
  end
end
