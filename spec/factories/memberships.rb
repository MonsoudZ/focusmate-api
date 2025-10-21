FactoryBot.define do
  factory :membership do
    list { association :list }
    user { association :user }
    role { "editor" }

    trait :viewer do
      role { "viewer" }
    end

    trait :editor do
      role { "editor" }
    end
  end
end
