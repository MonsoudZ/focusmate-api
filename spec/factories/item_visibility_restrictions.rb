FactoryBot.define do
  factory :item_visibility_restriction do
    coaching_relationship { association :coaching_relationship }
    task { association :task }
  end
end
