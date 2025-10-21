FactoryBot.define do
  factory :daily_summary do
    coaching_relationship { association :coaching_relationship }
    summary_date { Date.current }
    tasks_completed { 5 }
    tasks_missed { 2 }
    tasks_overdue { 1 }
    sent { false }

    trait :sent do
      sent { true }
      sent_at { Time.current }
    end

    trait :with_performance_data do
      summary_data do
        {
          date: summary_date.iso8601,
          client_name: coaching_relationship.client.name,
          coach_name: coaching_relationship.coach.name,
          total_tasks: tasks_completed + tasks_missed,
          completion_rate: (tasks_completed.to_f / (tasks_completed + tasks_missed) * 100).round(1),
          performance_notes: "#{tasks_completed} tasks completed, #{tasks_missed} tasks missed"
        }
      end
    end
  end
end
