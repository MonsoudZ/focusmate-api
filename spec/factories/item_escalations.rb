FactoryBot.define do
  factory :item_escalation do
    escalation_level { "normal" }
    notification_count { 0 }
    coaches_notified { false }
    blocking_app { false }
    task { association :task }

    trait :warning do
      escalation_level { "warning" }
      notification_count { 3 }
      last_notification_at { 1.hour.ago }
    end

    trait :critical do
      escalation_level { "critical" }
      notification_count { 5 }
      last_notification_at { 30.minutes.ago }
      became_overdue_at { 2.hours.ago }
    end

    trait :blocking do
      escalation_level { "blocking" }
      notification_count { 7 }
      last_notification_at { 15.minutes.ago }
      became_overdue_at { 3.hours.ago }
      blocking_app { true }
      blocking_started_at { 1.hour.ago }
    end

    trait :coaches_notified do
      coaches_notified { true }
      coaches_notified_at { 1.hour.ago }
    end

    trait :overdue do
      became_overdue_at { 1.hour.ago }
    end
  end
end
