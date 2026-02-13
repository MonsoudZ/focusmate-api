FactoryBot.define do
  factory :notification_preference do
    user { association :user }

    trait :all_disabled do
      nudge_enabled { false }
      task_assigned_enabled { false }
      list_joined_enabled { false }
      task_reminder_enabled { false }
    end
  end
end
