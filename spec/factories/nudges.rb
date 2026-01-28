FactoryBot.define do
  factory :nudge do
    task
    from_user { association :user }
    to_user { association :user }
  end
end
