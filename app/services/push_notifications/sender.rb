# frozen_string_literal: true

require "apnotic"
require "base64"

module PushNotifications
  class Sender
    CONNECTION_MUTEX = Mutex.new
    @connection = nil
    @temp_key_file = nil

    class << self
      def send_to_user(user:, title:, body:, data: {})
        notification_type = data[:type]&.to_sym
        return false if notification_type && !NotificationPreference.enabled_for_user?(user, notification_type)

        devices = user.devices.ios.active

        return false if devices.empty?

        sent_count = 0
        devices.each do |device|
          sent_count += 1 if send_to_device(device: device, title: title, body: body, data: data)
        end

        sent_count.positive?
      end

      def send_to_device(device:, title:, body:, data: {})
        return false unless device.apns_token.present?

        notification = build_notification(
          token: device.apns_token,
          title: title,
          body: body,
          data: data
        )

        push = connection.push_async(notification)
        push.on(:response) do |response|
          handle_apns_response(response, device)
        end

        Rails.logger.info("Push sent to device #{device.id}: #{title}")
        true
      rescue StandardError => e
        Rails.logger.error("Push failed for device #{device.id}: #{e.message}")

        # Reset connection on connection-related errors
        if connection_error?(e)
          Rails.logger.warn("APNS connection error detected, resetting connection")
          reset_connection!
        end

        Sentry.capture_exception(e) if defined?(Sentry)
        false
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

      def send_list_joined(to_user:, new_member:, list:)
        send_to_user(
          user: to_user,
          title: "#{new_member.name} joined your list",
          body: "#{new_member.name} is now a member of \"#{list.name}\"",
          data: {
            type: "list_joined",
            list_id: list.id,
            user_id: new_member.id
          }
        )
      end

      def send_task_assigned(to_user:, task:, assigned_by:)
        send_to_user(
          user: to_user,
          title: "New task assigned to you",
          body: "#{assigned_by.name} assigned you: #{task.title}",
          data: {
            type: "task_assigned",
            task_id: task.id,
            list_id: task.list_id,
            assigned_by_id: assigned_by.id
          }
        )
      end

      def send_task_reminder(to_user:, task:)
        send_to_user(
          user: to_user,
          title: "Task due soon",
          body: task.title,
          data: {
            type: "task_reminder",
            task_id: task.id,
            list_id: task.list_id
          }
        )
      end

      # Reset connection (useful for testing or after errors)
      def reset_connection!
        CONNECTION_MUTEX.synchronize do
          close_connection!
          @connection = nil
          cleanup_temp_file!
        end
      end

      private

      def connection
        CONNECTION_MUTEX.synchronize do
          @connection ||= create_connection
        end
      end

      def create_connection
        cert_path = resolve_cert_path

        Apnotic::Connection.new(
          auth_method: :token,
          cert_path: cert_path,
          key_id: Rails.application.credentials.dig(:apns, :key_id) || ENV.fetch("APNS_KEY_ID"),
          team_id: Rails.application.credentials.dig(:apns, :team_id) || ENV.fetch("APNS_TEAM_ID"),
          topic: Rails.application.credentials.dig(:apns, :bundle_id) || ENV.fetch("APNS_BUNDLE_ID")
        )
      end

      # Called inside CONNECTION_MUTEX from create_connection → connection
      def resolve_cert_path
        apns_key_content = Rails.application.credentials.dig(:apns, :key_content) || ENV["APNS_KEY_CONTENT"]
        if apns_key_content.present?
          # Production: key content is base64-encoded in credentials or env var
          key_content = Base64.decode64(apns_key_content)

          # Clean up any existing temp file before creating new one
          cleanup_temp_file!

          # Write to temp file (apnotic requires a file path)
          @temp_key_file = Tempfile.new([ "apns_key", ".p8" ])
          @temp_key_file.write(key_content)
          @temp_key_file.close
          @temp_key_file.path
        else
          # Development: use local file path
          key_path = ENV.fetch("APNS_KEY_PATH", "config/apns/sandbox.p8")
          Rails.root.join(key_path).to_s
        end
      end

      # Always called inside CONNECTION_MUTEX (from reset_connection! or resolve_cert_path)
      def cleanup_temp_file!
        return unless @temp_key_file

        @temp_key_file.close unless @temp_key_file.closed?
        @temp_key_file.unlink
      rescue Errno::ENOENT
        nil
      rescue StandardError => e
        Rails.logger.warn("APNS temp key cleanup failed: #{e.message}")
      ensure
        @temp_key_file = nil
      end

      def close_connection!
        return unless @connection

        @connection.close
      rescue StandardError => e
        Rails.logger.warn("APNS connection close failed: #{e.message}")
      end

      def connection_error?(error)
        # Check for connection-related errors that warrant a reconnect
        error_message = error.message.to_s.downcase
        error_message.include?("connection") ||
          error_message.include?("socket") ||
          error_message.include?("eof") ||
          error_message.include?("closed") ||
          error.is_a?(IOError) ||
          error.is_a?(Errno::ECONNRESET) ||
          error.is_a?(Errno::EPIPE)
      end

      def handle_apns_response(response, device)
        return if response.ok?

        status = response.status
        body = response.body

        Rails.logger.warn(
          "APNS response error for device #{device.id}: status=#{status} reason=#{body}"
        )

        # Deactivate device on unrecoverable token errors
        if %w[BadDeviceToken Unregistered ExpiredProviderToken].include?(body.to_s)
          device.update_columns(active: false, updated_at: Time.current)
          Rails.logger.info("Deactivated stale device #{device.id} (reason: #{body})")
        end
      rescue StandardError => e
        Rails.logger.error("Error handling APNS response for device #{device.id}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end

      def build_notification(token:, title:, body:, data: {})
        notification = Apnotic::Notification.new(token)
        notification.alert = { title: title, body: body }
        notification.sound = "default"
        notification.custom_payload = data if data.present?
        notification.topic = Rails.application.credentials.dig(:apns, :bundle_id) || ENV.fetch("APNS_BUNDLE_ID")
        notification
      end
    end
  end
end
