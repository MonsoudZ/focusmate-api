# db/seeds.rb
# Seeds for Intentia MVP Testing
# Run: rails db:seed

puts "🌱 Starting seed process..."

# Only run in development/staging, never production
if Rails.env.production?
  puts "❌ Cannot run seeds in production!"
  exit
end

# Clean up existing data
puts "Cleaning up existing data..."
Task.destroy_all
List.destroy_all
Membership.destroy_all
User.destroy_all

puts "Creating test users..."

# Main test user
user1 = User.create!(
  email: 'test@intentia.app',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Test User',
  timezone: 'America/New_York'
)

# Secondary user for sharing tests
user2 = User.create!(
  email: 'shared@intentia.app',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Shared User',
  timezone: 'America/New_York'
)

puts "✅ Created #{User.count} users"

# Create lists for main user
puts "Creating lists..."

inbox = List.create!(
  name: 'Inbox',
  description: 'Default inbox for quick tasks',
  user: user1,
  visibility: 'private'
)

work = List.create!(
  name: 'Work',
  description: 'Work projects and tasks',
  user: user1,
  visibility: 'private'
)

personal = List.create!(
  name: 'Personal',
  description: 'Personal tasks and errands',
  user: user1,
  visibility: 'private'
)

shared_list = List.create!(
  name: 'Shared Project',
  description: 'A list shared with another user',
  user: user1,
  visibility: 'shared'
)

puts "✅ Created #{List.count} lists"

# Create tasks with various states
puts "Creating tasks..."

# Overdue tasks (due in the past)
Task.create!(
  list: inbox,
  title: 'Overdue task - needs reason',
  note: 'This task is overdue and requires an explanation',
  due_at: 2.days.ago,
  creator: user1,
  status: 0, # pending
  requires_explanation_if_missed: true,

)

Task.create!(
  list: work,
  title: 'Missed deadline - submit report',
  note: 'Weekly report was due',
  due_at: 1.day.ago,
  creator: user1,
  status: 0,
  requires_explanation_if_missed: true,

)

# Due today
Task.create!(
  list: inbox,
  title: 'Due today - morning standup',
  note: 'Team sync meeting',
  due_at: Time.current.change(hour: 9, min: 0),
  creator: user1,
  status: 0,

)

Task.create!(
  list: work,
  title: 'Due today - review PR',
  note: 'Review pull request #42',
  due_at: Time.current.change(hour: 14, min: 0),
  creator: user1,
  status: 0,

)

Task.create!(
  list: personal,
  title: 'Due today - call mom',
  note: 'Weekly catch-up call',
  due_at: Time.current.change(hour: 18, min: 0),
  creator: user1,
  status: 0,

)

# Due tomorrow
Task.create!(
  list: work,
  title: 'Tomorrow - prepare presentation',
  note: 'Q4 results presentation',
  due_at: 1.day.from_now.change(hour: 10, min: 0),
  creator: user1,
  status: 0,

)

# Due this week
Task.create!(
  list: personal,
  title: 'This week - gym session',
  note: 'Leg day',
  due_at: 3.days.from_now.change(hour: 7, min: 0),
  creator: user1,
  status: 0,

)

Task.create!(
  list: work,
  title: 'This week - deploy to production',
  note: 'Deploy v2.0 release',
  due_at: 4.days.from_now.change(hour: 15, min: 0),
  creator: user1,
  status: 0,
  strict_mode: true,
  requires_explanation_if_missed: true
)

# Completed tasks
Task.create!(
  list: inbox,
  title: 'Completed - setup project',
  note: 'Initial project setup',
  due_at: 1.day.ago,
  creator: user1,
  status: 1, # completed
  completed_at: 1.day.ago
)

Task.create!(
  list: work,
  title: 'Completed - write tests',
  note: 'Unit tests for auth module',
  due_at: 2.days.ago,
  creator: user1,
  status: 1,
  completed_at: 2.days.ago
)

Task.create!(
  list: personal,
  title: 'Completed - buy groceries',
  note: 'Weekly shopping',
  due_at: 3.days.ago,
  creator: user1,
  status: 1,
  completed_at: 3.days.ago
)

# Task in shared list
Task.create!(
  list: shared_list,
  title: 'Shared task - collaborate on doc',
  note: 'Work on shared document together',
  due_at: 2.days.from_now,
  creator: user1,
  status: 0,

)

puts "✅ Created #{Task.count} tasks"

# Print summary
puts "\n" + "=" * 60
puts "🎉 Seed completed successfully!"
puts "=" * 60
puts "\n📊 Summary:"
puts "  Users: #{User.count}"
puts "  Lists: #{List.count}"
puts "  Tasks: #{Task.count}"
puts "    - Overdue: #{Task.where('due_at < ? AND completed_at IS NULL', Time.current).count}"
puts "    - Due today: #{Task.where('due_at >= ? AND due_at < ? AND completed_at IS NULL', Time.current.beginning_of_day, Time.current.end_of_day).count}"
puts "    - Completed: #{Task.where.not(completed_at: nil).count}"
puts "\n🔑 Test Credentials:"
puts "  Main user: test@intentia.app / password123"
puts "  Shared user: shared@intentia.app / password123"
puts "=" * 60
