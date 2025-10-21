FactoryBot.define do
  factory :saved_location do
    name { Faker::Address.city }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    radius_meters { 100 }
    user { association :user }

    trait :with_small_radius do
      radius_meters { 50 }
    end

    trait :with_large_radius do
      radius_meters { 500 }
    end
  end
end
