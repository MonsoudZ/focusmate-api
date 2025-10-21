FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence(word_count: 4) }
    due_at { 1.day.from_now }
    status { "pending" }
    visibility { "visible_to_all" }
    strict_mode { false }
    requires_explanation_if_missed { false }
    list { association :list }
    creator { association :user }

    trait :overdue do
      due_at { 1.day.ago }
      status { "pending" }
    end

    trait :completed do
      status { "completed" }
      completed_at { 1.hour.ago }
    end

    trait :requires_explanation do
      requires_explanation_if_missed { true }
      due_at { 1.day.ago }
      status { "pending" }
    end

    trait :with_subtasks do
      after(:create) do |task|
        create_list(:task, 2, parent_task: task, list: task.list, creator: task.creator)
      end
    end
  end
end
