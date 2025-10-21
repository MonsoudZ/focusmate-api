FactoryBot.define do
  factory :notification_log do
    notification_type { "task_reminder" }
    delivered { true }
    metadata { { "read" => false } }
    user { association :user }

    trait :undelivered do
      delivered { false }
    end

    trait :read do
      metadata { { "read" => true } }
    end
  end
end
