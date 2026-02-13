FactoryBot.define do
  factory :device do
    platform { "ios" }
    apns_token { SecureRandom.hex(32) }  # 64 hex characters
    bundle_id { "com.intentia.app" }
    user { association :user }

    # Auto-set FCM token for Android devices (only if not already set)
    after(:build) do |device|
      if device.platform == "android" && device.fcm_token.blank?
        device.apns_token = nil
        device.fcm_token = SecureRandom.alphanumeric(163)
      end
    end

    trait :android do
      platform { "android" }
      apns_token { nil }
      fcm_token { SecureRandom.alphanumeric(163) }  # 163 characters as expected by tests
    end
  end
end
