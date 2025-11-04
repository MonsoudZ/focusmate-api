# Seeds for iOS App Testing
# This script creates test data that matches the iOS app's expectations

puts "🌱 Starting seed process..."

# Clean up existing data (optional - comment out if you want to keep existing data)
puts "Cleaning up existing data..."
Task.unscoped.destroy_all
List.unscoped.destroy_all
ListShare.destroy_all
User.where(email: ['coach@test.com', 'client@test.com']).destroy_all

puts "Creating test users..."

# Create a client user
client = User.create!(
  email: 'client@test.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Test Client',
  role: 'client',
  timezone: 'America/New_York'
)

# Create a coach user
coach = User.create!(
  email: 'coach@test.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Test Coach',
  role: 'coach',
  timezone: 'America/New_York'
)

puts "✅ Created users: #{client.email}, #{coach.email}"

# Create coaching relationship
coaching_relationship = CoachingRelationship.create!(
  coach: coach,
  client: client,
  status: 'active',
  invited_by: 'coach',
  accepted_at: Time.current
)

puts "✅ Created coaching relationship"

# Create lists for client
puts "Creating lists..."

personal_list = List.create!(
  name: 'Personal Tasks',
  description: 'My personal task list',
  visibility: 'private',
  user: client
)

work_list = List.create!(
  name: 'Work Projects',
  description: 'Work-related tasks and projects',
  visibility: 'private',
  user: client
)

shared_list = List.create!(
  name: 'Shared with Coach',
  description: 'Tasks visible to my coach',
  visibility: 'shared',
  user: client
)

puts "✅ Created #{List.count} lists"

# Create list shares
ListShare.create!(
  list: personal_list,
  user: client,
  email: client.email,
  role: 'admin',
  status: 'accepted',
  can_view: true,
  can_edit: true,
  can_add_items: true,
  can_delete_items: true,
  receive_notifications: true,
  accepted_at: Time.current
)

ListShare.create!(
  list: work_list,
  user: client,
  email: client.email,
  role: 'admin',
  status: 'accepted',
  can_view: true,
  can_edit: true,
  can_add_items: true,
  can_delete_items: true,
  receive_notifications: true,
  accepted_at: Time.current
)

ListShare.create!(
  list: shared_list,
  user: client,
  email: client.email,
  role: 'admin',
  status: 'accepted',
  can_view: true,
  can_edit: true,
  can_add_items: true,
  can_delete_items: true,
  receive_notifications: true,
  accepted_at: Time.current
)

# Share with coach
ListShare.create!(
  list: shared_list,
  user: coach,
  email: coach.email,
  role: 'editor',
  status: 'accepted',
  can_view: true,
  can_edit: true,
  can_add_items: true,
  can_delete_items: false,
  receive_notifications: true,
  accepted_at: Time.current
)

puts "✅ Created list shares"

# Create tasks
puts "Creating tasks..."

# Personal list tasks
Task.create!(
  list: personal_list,
  title: 'Morning workout',
  note: 'Gym session - cardio and weights',
  due_at: Time.current + 2.hours,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  can_be_snoozed: true,
  notification_interval_minutes: 15,
  requires_explanation_if_missed: false
)

Task.create!(
  list: personal_list,
  title: 'Buy groceries',
  note: 'Milk, eggs, bread, vegetables',
  due_at: Time.current + 5.hours,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  can_be_snoozed: true,
  notification_interval_minutes: 30
)

completed_task = Task.create!(
  list: personal_list,
  title: 'Read chapter 5',
  note: 'Finish reading chapter 5 of "Atomic Habits"',
  due_at: Time.current + 1.hour,
  creator: client,
  visibility: 'visible_to_all',
  status: 'done',
  completed_at: Time.current - 1.hour,
  can_be_snoozed: false
)

# Work list tasks
Task.create!(
  list: work_list,
  title: 'Team standup meeting',
  note: 'Daily standup with the development team',
  due_at: Time.current.tomorrow.change(hour: 9, min: 0),
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  strict_mode: true,
  can_be_snoozed: false,
  notification_interval_minutes: 10,
  requires_explanation_if_missed: true
)

Task.create!(
  list: work_list,
  title: 'Finish API documentation',
  note: 'Complete documentation for REST API endpoints',
  due_at: Time.current.tomorrow.change(hour: 17, min: 0),
  creator: client,
  visibility: 'visible_to_all',
  status: 'in_progress',
  can_be_snoozed: true,
  notification_interval_minutes: 60
)

Task.create!(
  list: work_list,
  title: 'Code review - PR #234',
  note: 'Review authentication refactor pull request',
  due_at: Time.current + 3.hours,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  can_be_snoozed: true,
  notification_interval_minutes: 20
)

# Shared list tasks (visible to coach)
Task.create!(
  list: shared_list,
  title: 'Weekly goal review',
  note: 'Review progress on weekly goals with coach',
  due_at: Time.current + 1.day,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  strict_mode: true,
  can_be_snoozed: false,
  notification_interval_minutes: 30,
  requires_explanation_if_missed: true
)

coach_created_task = Task.create!(
  list: shared_list,
  title: 'Practice meditation',
  note: 'Daily meditation practice - 10 minutes',
  due_at: Time.current.tomorrow.change(hour: 7, min: 0),
  creator: coach,
  visibility: 'visible_to_all',
  status: 'pending',
  can_be_snoozed: false,
  notification_interval_minutes: 5,
  requires_explanation_if_missed: true
)

# Create an overdue task (note: due_at must be future, will become overdue naturally)
overdue_task = Task.create!(
  list: shared_list,
  title: 'Submit weekly report',
  note: 'Weekly progress report for coaching session',
  due_at: Time.current + 30.minutes,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  strict_mode: true,
  can_be_snoozed: false,
  notification_interval_minutes: 15,
  requires_explanation_if_missed: true
)

# Create a recurring task
Task.create!(
  list: personal_list,
  title: 'Daily journaling',
  note: 'Write in journal for 10 minutes',
  due_at: Time.current.tomorrow.change(hour: 21, min: 0),
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  is_recurring: true,
  recurrence_pattern: 'daily',
  recurrence_interval: 1,
  recurrence_time: Time.current.change(hour: 21, min: 0),
  can_be_snoozed: true,
  notification_interval_minutes: 15
)

# Create a location-based task
Task.create!(
  list: personal_list,
  title: 'Pick up dry cleaning',
  note: 'Get shirts from cleaners',
  due_at: Time.current + 2.days,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  location_based: true,
  location_name: 'Downtown Dry Cleaners',
  location_latitude: 40.7580,
  location_longitude: -73.9855,
  location_radius_meters: 100,
  notify_on_arrival: true,
  notify_on_departure: false,
  can_be_snoozed: true
)

puts "✅ Created #{Task.count} tasks"

# Create some subtasks
puts "Creating subtasks..."

main_task = Task.create!(
  list: work_list,
  title: 'Prepare presentation',
  note: 'Quarterly results presentation for stakeholders',
  due_at: Time.current + 2.days,
  creator: client,
  visibility: 'visible_to_all',
  status: 'in_progress',
  can_be_snoozed: true
)

subtask1 = Task.create!(
  list: work_list,
  parent_task: main_task,
  title: 'Gather data',
  note: 'Collect Q4 metrics and analytics',
  due_at: Time.current + 1.day,
  creator: client,
  visibility: 'visible_to_all',
  status: 'done',
  completed_at: Time.current - 2.hours,
  can_be_snoozed: false
)

subtask2 = Task.create!(
  list: work_list,
  parent_task: main_task,
  title: 'Create slides',
  note: 'Design presentation slides',
  due_at: Time.current + 1.day + 6.hours,
  creator: client,
  visibility: 'visible_to_all',
  status: 'in_progress',
  can_be_snoozed: false
)

subtask3 = Task.create!(
  list: work_list,
  parent_task: main_task,
  title: 'Practice delivery',
  note: 'Rehearse presentation',
  due_at: Time.current + 1.day + 12.hours,
  creator: client,
  visibility: 'visible_to_all',
  status: 'pending',
  can_be_snoozed: false
)

puts "✅ Created #{Task.where.not(parent_task_id: nil).count} subtasks"

# Print summary
puts "\n" + "="*60
puts "🎉 Seed completed successfully!"
puts "="*60
puts "\n📊 Summary:"
puts "  Users: #{User.count}"
puts "  Lists: #{List.count}"
puts "  Tasks: #{Task.count} (#{Task.where(parent_task_id: nil).count} main tasks, #{Task.where.not(parent_task_id: nil).count} subtasks)"
puts "  Coaching Relationships: #{CoachingRelationship.count}"
puts "\n🔑 Test Credentials:"
puts "  Client: client@test.com / password123"
puts "  Coach:  coach@test.com / password123"
puts "\n📝 Task IDs for testing:"
Task.where(parent_task_id: nil).limit(5).each do |task|
  status_emoji = task.status == 'done' ? '✅' : task.due_at < Time.current ? '⏰' : '📌'
  puts "  #{status_emoji} Task ##{task.id}: #{task.title} (#{task.status})"
end
puts "="*60
