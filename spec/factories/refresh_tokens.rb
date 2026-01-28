# frozen_string_literal: true

FactoryBot.define do
  factory :refresh_token do
    user
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    jti { SecureRandom.uuid }
    family { SecureRandom.uuid }
    expires_at { 30.days.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
