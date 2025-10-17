# frozen_string_literal: true
module Notifications
  class Push
    def self.apns
      @apns ||= Apns::Client.new
    end

    def self.send_example(device_token, title:, body:)
      payload = {
        aps: {
          alert: { title: title, body: body },
          sound: "default",
          badge: 1
        }
      }
      apns.send_notification(device_token, payload, push_type: "alert")
    end

    # Send notification with full control
    def self.send_notification(device_token, payload, options = {})
      apns.send_notification(device_token, payload, options)
    end

    # Send critical alert
    def self.send_critical_alert(device_token, title:, body:, badge: nil)
      payload = {
        aps: {
          alert: { title: title, body: body },
          sound: {
            critical: 1,
            name: "critical.caf",
            volume: 1.0
          },
          badge: badge
        }
      }
      apns.send_notification(
        device_token, 
        payload, 
        push_type: "alert",
        priority: 10
      )
    end

    # Send background notification
    def self.send_background_update(device_token, data: {})
      payload = {
        aps: {
          "content-available" => 1
        }
      }.merge(data)
      
      apns.send_notification(
        device_token,
        payload,
        push_type: "background",
        priority: 5
      )
    end

    # Send VoIP notification
    def self.send_voip_notification(device_token, payload, bundle_id: nil)
      topic = bundle_id ? "#{bundle_id}.voip" : nil
      apns.send_notification(
        device_token,
        payload,
        push_type: "voip",
        topic: topic,
        priority: 10
      )
    end

    # Health check - send to a test token
    def self.health_check(test_token)
      result = send_example(test_token, title: "Health Check", body: "APNs connection test")
      {
        healthy: result[:ok],
        status: result[:status],
        reason: result[:reason]
      }
    end
  end
end
