FactoryBot.define do
  factory :list do
    name { Faker::Lorem.words(number: 3).join(" ").titleize }
    description { Faker::Lorem.sentence }
    visibility { "private" }
    user { association :user }

    trait :public do
      visibility { "public" }
    end

    trait :shared do
      visibility { "shared" }
    end
  end
end
