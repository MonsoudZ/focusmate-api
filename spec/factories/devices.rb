FactoryBot.define do
  factory :device do
    platform { "ios" }
    apns_token { Faker::Alphanumeric.alphanumeric(number: 64) }
    bundle_id { "com.focusmate.app" }
    user { association :user }

    trait :android do
      platform { "android" }
      apns_token { nil }
    end
  end
end
