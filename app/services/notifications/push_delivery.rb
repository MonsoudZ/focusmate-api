# frozen_string_literal: true

module Notifications
  class PushDelivery
    def self.call!(user:, event:, payload:)
      devices = user.devices.where(platform: "ios")
      return if devices.none?

      devices.find_each do |device|
        Notifications::ApnsClient.deliver!(
          token: device.apns_token,
          payload: build_apns_payload(event, payload)
        )
      end
    end

    def self.build_apns_payload(event, payload)
      {
        aps: {
          alert: {
            title: payload.fetch(:title),
            body: payload.fetch(:body)
          },
          sound: "default"
        },
        event: event,
        data: payload.fetch(:data, {})
      }
    end

    private_class_method :build_apns_payload
  end
end
