FactoryBot.define do
  factory :task_event do
    task
    user        { association :user }
    kind        { :created }
    occurred_at { Time.current }
    reason      { nil }
  end
end
