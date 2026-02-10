# frozen_string_literal: true

FactoryBot.define do
  factory :task_tag do
    task { association :task }
    tag { association :tag }
  end
end
