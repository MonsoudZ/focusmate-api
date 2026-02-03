# frozen_string_literal: true

FactoryBot.define do
  factory :reschedule_event do
    task
    user { nil }
    previous_due_at { 1.day.ago }
    new_due_at { 1.day.from_now }
    reason { "priorities_shifted" }
  end
end
