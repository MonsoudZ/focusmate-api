FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123" }
    password_confirmation { "password123" }
    role { "client" }
    name { Faker::Name.name }
    timezone { "America/New_York" }

    trait :coach do
      role { "coach" }
    end

    trait :client do
      role { "client" }
    end

    trait :with_location do
      current_latitude { 40.7128 }
      current_longitude { -74.0060 }
    end

    trait :with_devices do
      after(:create) do |user|
        create(:device, user: user)
      end
    end

  end
end
