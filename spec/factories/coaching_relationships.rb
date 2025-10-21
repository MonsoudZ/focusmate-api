FactoryBot.define do
  factory :coaching_relationship do
    coach { association :user, :coach }
    client { association :user, :client }
    invited_by { association :user, :coach }
    status { "active" }

    trait :inactive do
      status { "inactive" }
    end
  end
end
