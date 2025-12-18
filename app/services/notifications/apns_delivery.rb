# frozen_string_literal: true

module Notifications
  class ApnsDelivery
    Result = Struct.new(:sent, :failed, :skipped, keyword_init: true)

    def self.call(user:, payload:)
      new(user:, payload:).call
    end

    def initialize(user:, payload:)
      @user = user
      @payload = payload
    end

    def call
      client = Apns.client
      return Result.new(sent: 0, failed: 0, skipped: device_count) unless client&.enabled?

      devices = @user.devices
                     .where(platform: "ios")
                     .where.not(apns_token: [ nil, "" ])
                     .where(active: true)

      sent = failed = skipped = 0

      devices.find_each do |device|
        begin
          resp = client.send_notification(
            device.apns_token,
            @payload,
            push_type: "alert",
            priority: 5,
            expiration: Time.now.to_i + 3600
          )

          if resp[:ok]
            sent += 1
          else
            case resp[:status]
            when 410 # Unregistered token
              device.update!(active: false)
              failed += 1
            when 429 # Rate limited
              # let Sidekiq retry whole job (keeps behavior consistent)
              raise StandardError, "APNs rate limit: #{resp[:reason]}"
            else
              failed += 1
            end
          end
        rescue => e
          raise e if e.message.include?("rate limit")
          failed += 1
        end
      end

      Result.new(sent: sent, failed: failed, skipped: skipped)
    end

    private

    def device_count
      @user.devices.where(platform: "ios", active: true).count
    rescue
      0
    end
  end
end
