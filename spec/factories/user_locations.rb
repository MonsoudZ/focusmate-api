FactoryBot.define do
  factory :user_location do
    association :user
    latitude    { 40.7128 }
    longitude   { -74.0060 }
    accuracy    { 10.0 }
    recorded_at { Time.current }
    source      { "gps" }
    metadata    { {} }
  end
end
