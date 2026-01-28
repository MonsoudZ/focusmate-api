# frozen_string_literal: true

require "apnotic"
require "base64"

module PushNotifications
  class Sender
    class << self
      def send_to_user(user:, title:, body:, data: {})
        devices = user.devices.ios.active

        return if devices.empty?

        devices.each do |device|
          send_to_device(device: device, title: title, body: body, data: data)
        end
      end

      def send_to_device(device:, title:, body:, data: {})
        return unless device.apns_token.present?

        notification = build_notification(
          token: device.apns_token,
          title: title,
          body: body,
          data: data
        )

        connection.push_async(notification)
        Rails.logger.info("Push sent to device #{device.id}: #{title}")
      rescue => e
        Rails.logger.error("Push failed for device #{device.id}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end

      def send_nudge(from_user:, to_user:, task:)
        send_to_user(
          user: to_user,
          title: "Nudge from #{from_user.name}",
          body: "#{from_user.name} is reminding you about: #{task.title}",
          data: {
            type: "nudge",
            task_id: task.id,
            list_id: task.list_id,
            from_user_id: from_user.id
          }
        )
      end

      private

      def connection
        @connection ||= begin
                          # Check if key content is provided via env var (for Railway/production)
                          if ENV["APNS_KEY_CONTENT"].present?
                            key_content = Base64.decode64(ENV["APNS_KEY_CONTENT"])

                            # Write to a temp file since apnotic requires a file path.
                            # Store as @temp_key_file so the file persists alongside @connection.
                            @temp_key_file = Tempfile.new([ "apns_key", ".p8" ])
                            @temp_key_file.write(key_content)
                            @temp_key_file.close
                            cert_path = @temp_key_file.path
                          else
                            # Fall back to file path for local development
                            key_path = ENV.fetch("APNS_KEY_PATH", "config/apns/sandbox.p8")
                            cert_path = Rails.root.join(key_path)
                          end

                          Apnotic::Connection.new(
                            auth_method: :token,
                            cert_path: cert_path,
                            key_id: ENV.fetch("APNS_KEY_ID"),
                            team_id: ENV.fetch("APNS_TEAM_ID"),
                            topic: ENV.fetch("APNS_BUNDLE_ID")
                          )
                        end
      end

      def build_notification(token:, title:, body:, data: {})
        notification = Apnotic::Notification.new(token)
        notification.alert = { title: title, body: body }
        notification.sound = "default"
        notification.custom_payload = data if data.present?
        notification.topic = ENV.fetch("APNS_BUNDLE_ID")
        notification
      end
    end
  end
end
