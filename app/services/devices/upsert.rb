# frozen_string_literal: true

module Devices
  class Upsert
    def self.call!(user:, apns_token:, **attrs)
      new(user:, apns_token:, attrs:).call!
    end

    def initialize(user:, apns_token:, attrs:)
      @user = user
      @token = apns_token.to_s.strip
      @attrs = attrs.compact
    end

    def call!
      raise ApplicationError::BadRequest, "apns_token is required" if @token.blank?

      device = @user.devices.find_or_initialize_by(apns_token: @token)
      device.assign_attributes(@attrs)
      device.platform ||= "ios"
      device.last_seen_at = Time.current if device.respond_to?(:last_seen_at)
      device.save!
      device
    end
  end
end
