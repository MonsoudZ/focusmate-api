FactoryBot.define do
  factory :task_event do
    task
    user        { association :user }
    kind        { :created }
    occurred_at { 1.hour.ago }  # Default to 1 hour ago
    reason      { nil }
  end
end
