# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_event do
    user { association :user }
    event_type { "task_created" }
    occurred_at { Time.current }
  end
end
