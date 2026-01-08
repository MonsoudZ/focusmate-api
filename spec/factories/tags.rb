FactoryBot.define do
  factory :tag do
    name { Faker::Lorem.word.capitalize }
    color { %w[blue green red yellow purple orange pink].sample }
    user { association :user }
  end
end
