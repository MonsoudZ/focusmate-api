FactoryBot.define do
  factory :list_share do
    list { association :list }
    user { association :user }
    email { user&.email || Faker::Internet.email }
    role { "viewer" }
    status { "accepted" }
    can_view { true }
    can_edit { false }
    can_add_items { false }
    can_delete_items { false }
    receive_notifications { true }

    trait :editor do
      role { "editor" }
      can_edit { true }
      can_add_items { true }
      can_delete_items { true }
    end

    trait :viewer do
      role { "viewer" }
      can_view { true }
      can_edit { false }
    end

    trait :pending do
      status { "pending" }
    end

    trait :accepted do
      status { "accepted" }
    end

    trait :declined do
      status { "declined" }
    end
  end
end
