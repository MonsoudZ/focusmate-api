FactoryBot.define do
  factory :list_invite do
    list
    inviter { association :user }
    role { "viewer" }
    expires_at { nil }
    max_uses { nil }
    uses_count { 0 }

    trait :editor do
      role { "editor" }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :exhausted do
      max_uses { 1 }
      uses_count { 1 }
    end

    trait :limited do
      max_uses { 5 }
    end
  end
end
