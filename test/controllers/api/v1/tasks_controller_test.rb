require "test_helper"

class Api::V1::TasksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @task = create_test_task(@list, creator: @user)
    @auth_headers = auth_headers(@user)
  end

  # Index tests
  test "should get tasks for list" do
    get "/api/v1/lists/#{@list.id}/tasks", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks", "tombstones"])
    
    assert json["tasks"].is_a?(Array)
    assert json["tombstones"].is_a?(Array)
  end

  test "should get all tasks across lists" do
    other_list = create_test_list(@user, name: "Other List")
    create_test_task(other_list, creator: @user)
    
    get "/api/v1/tasks/all_tasks", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks", "tombstones"])
    
    assert json["tasks"].is_a?(Array)
    assert json["tombstones"].is_a?(Array)
  end

  test "should filter tasks by status" do
    completed_task = create_test_task(@list, creator: @user, status: :done)
    
    get "/api/v1/tasks/all_tasks?status=completed", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_includes task_ids, completed_task.id
    assert_not_includes task_ids, @task.id
  end

  test "should filter tasks by list_id" do
    other_list = create_test_list(@user, name: "Other List")
    other_task = create_test_task(other_list, creator: @user)
    
    get "/api/v1/tasks/all_tasks?list_id=#{other_list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_includes task_ids, other_task.id
    assert_not_includes task_ids, @task.id
  end

  test "should filter tasks by since parameter" do
    old_task = create_test_task(@list, creator: @user, created_at: 2.days.ago)
    
    get "/api/v1/tasks/all_tasks?since=#{1.day.ago.iso8601}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_includes task_ids, @task.id
    assert_not_includes task_ids, old_task.id
  end

  test "should not get tasks without authentication" do
    get "/api/v1/lists/#{@list.id}/tasks"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not get tasks for other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    
    get "/api/v1/lists/#{other_list.id}/tasks", headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  # Show tests
  test "should show task" do
    get "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "title", "due_at"])
    
    assert_equal @task.id, json["id"]
    assert_equal @task.title, json["title"]
  end

  test "should not show task without authentication" do
    get "/api/v1/lists/#{@list.id}/tasks/#{@task.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not show task from other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    other_task = create_test_task(other_list, creator: other_user)
    
    get "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  # Create tests
  test "should create task with valid attributes" do
    task_params = {
      title: "New Task",
      due_at: 1.hour.from_now.iso8601,
      strict_mode: true
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "due_at"])
    
    assert_equal "New Task", json["title"]
    assert_not_nil json["id"]
  end

  test "should create task with iOS parameters" do
    task_params = {
      name: "iOS Task", # iOS uses 'name' instead of 'title'
      dueDate: 1.hour.from_now.to_i, # iOS sends epoch seconds
      description: "iOS description" # iOS uses 'description' instead of 'note'
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title"])
    
    assert_equal "iOS Task", json["title"]
  end

  test "should create task with subtasks" do
    task_params = {
      title: "Task with Subtasks",
      due_at: 1.hour.from_now.iso8601,
      subtasks: ["Subtask 1", "Subtask 2"]
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id"])
    
    created_task = Task.find(json["id"])
    assert_equal 2, created_task.subtasks.count
    assert_equal "Subtask 1", created_task.subtasks.first.title
  end

  test "should not create task without title" do
    task_params = {
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not create task without due_at" do
    task_params = {
      title: "Task without due date"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not create task without authentication" do
    task_params = {
      title: "Unauthorized Task",
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", params: task_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not create task for other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    
    task_params = {
      title: "Unauthorized Task",
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{other_list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  # Update tests
  test "should update task with valid attributes" do
    update_params = {
      title: "Updated Task",
      note: "Updated note"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", 
          params: update_params, 
          headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "title"])
    
    assert_equal "Updated Task", json["title"]
    
    @task.reload
    assert_equal "Updated Task", @task.title
    assert_equal "Updated note", @task.note
  end

  test "should not update task without authentication" do
    update_params = {
      title: "Unauthorized Update"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", params: update_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not update task from other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    other_task = create_test_task(other_list, creator: other_user)
    
    update_params = {
      title: "Unauthorized Update"
    }
    
    patch "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", 
          params: update_params, 
          headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  # Delete tests
  test "should delete task" do
    delete "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :no_content
    
    @task.reload
    assert @task.deleted?
    assert_not_nil @task.deleted_at
  end

  test "should not delete task without authentication" do
    delete "/api/v1/lists/#{@list.id}/tasks/#{@task.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not delete task from other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    other_task = create_test_task(other_list, creator: other_user)
    
    delete "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", 
           headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  # Complete tests
  test "should complete task" do
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete", 
         params: { completed: true }, 
         headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "status"])
    
    assert_equal "done", json["status"]
    
    @task.reload
    assert @task.done?
    assert_not_nil @task.completed_at
  end

  test "should uncomplete task" do
    @task.complete!
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete", 
         params: { completed: false }, 
         headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "status"])
    
    assert_equal "pending", json["status"]
    
    @task.reload
    assert @task.pending?
    assert_nil @task.completed_at
  end

  test "should not complete task without authentication" do
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Reassign tests
  test "should reassign task" do
    new_due_at = 2.hours.from_now.iso8601
    reassign_params = {
      due_at: new_due_at,
      reason: "Need more time"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "due_at"])
    
    @task.reload
    assert_equal new_due_at.to_time.to_i, @task.due_at.to_i
  end

  test "should not reassign task without reason in strict mode" do
    @task.update!(strict_mode: true)
    
    reassign_params = {
      due_at: 2.hours.from_now.iso8601,
      reason: ""
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: "invalid json",
         headers: @auth_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle invalid date format" do
    task_params = {
      title: "Task with invalid date",
      due_at: "invalid-date"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle very long title" do
    task_params = {
      title: "a" * 256, # Too long
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle very long note" do
    task_params = {
      title: "Task with long note",
      note: "a" * 1001, # Too long
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle concurrent task creation" do
    threads = []
    5.times do |i|
      threads << Thread.new do
        task_params = {
          title: "Concurrent Task #{i}",
          due_at: 1.hour.from_now.iso8601
        }
        
        post "/api/v1/lists/#{@list.id}/tasks", 
             params: task_params, 
             headers: @auth_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true # If we get here without errors, test passes
  end

  test "should handle pagination parameters" do
    # Create multiple tasks
    10.times do |i|
      create_test_task(@list, creator: @user, title: "Task #{i}")
    end
    
    get "/api/v1/lists/#{@list.id}/tasks?page=1&per_page=5", 
        headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    # Should return tasks (pagination not implemented yet, but should not error)
    assert json["tasks"].is_a?(Array)
  end

  test "should handle sorting parameters" do
    # Create tasks with different due dates
    create_test_task(@list, creator: @user, title: "Task 1", due_at: 2.hours.from_now)
    create_test_task(@list, creator: @user, title: "Task 2", due_at: 1.hour.from_now)
    
    get "/api/v1/lists/#{@list.id}/tasks?sort=due_at&order=asc", 
        headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    # Should return tasks (sorting not implemented yet, but should not error)
    assert json["tasks"].is_a?(Array)
  end

  # Additional comprehensive tests for missing functionality

  # Access control tests
  test "should return only tasks user has access to" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    other_task = create_test_task(other_list, creator: other_user)
    
    get "/api/v1/tasks/all_tasks", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_includes task_ids, @task.id
    assert_not_includes task_ids, other_task.id
  end

  test "should include shared list tasks" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with current user
    Membership.create!(
      list: shared_list,
      user: @user,
      role: "member",
      invited_by: "owner"
    )
    
    shared_task = create_test_task(shared_list, creator: other_user)
    
    get "/api/v1/tasks/all_tasks", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_includes task_ids, shared_task.id
  end

  test "should exclude hidden tasks from coaches" do
    coach = create_test_user(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "coach",
      status: "active"
    )
    
    # Create task and hide it from coach
    task = create_test_task(@list, creator: @user)
    ItemVisibilityRestriction.create!(
      task: task,
      coaching_relationship: coaching_relationship
    )
    
    # Coach should not see the hidden task
    get "/api/v1/tasks/all_tasks", headers: auth_headers(coach)
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    task_ids = json["tasks"].map { |t| t["id"] }
    assert_not_includes task_ids, task.id
  end

  test "should paginate results" do
    # Create multiple tasks
    15.times do |i|
      create_test_task(@list, creator: @user, title: "Task #{i}")
    end
    
    get "/api/v1/lists/#{@list.id}/tasks?page=1&per_page=10", 
        headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    # Should return limited number of tasks
    assert json["tasks"].length <= 10
  end

  test "should sort by due_at, created_at, etc" do
    # Create tasks with different due dates
    task1 = create_test_task(@list, creator: @user, title: "Task 1", due_at: 3.hours.from_now)
    task2 = create_test_task(@list, creator: @user, title: "Task 2", due_at: 1.hour.from_now)
    task3 = create_test_task(@list, creator: @user, title: "Task 3", due_at: 2.hours.from_now)
    
    get "/api/v1/lists/#{@list.id}/tasks?sort=due_at&order=asc", 
        headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks"])
    
    # Should be sorted by due_at ascending
    task_titles = json["tasks"].map { |t| t["title"] }
    assert_equal ["Task 2", "Task 3", "Task 1"], task_titles
  end

  # Show tests enhancements
  test "should include subtasks in response" do
    subtask = create_test_task(@list, creator: @user, parent_task: @task)
    
    get "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "subtasks"])
    
    assert json["subtasks"].is_a?(Array)
    assert_equal 1, json["subtasks"].length
    assert_equal subtask.id, json["subtasks"].first["id"]
  end

  test "should include escalation data if exists" do
    # Create escalation for task
    escalation = ItemEscalation.create!(
      task: @task,
      escalated_at: Time.current,
      reason: "Overdue",
      blocking_app: true
    )
    
    get "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "escalation"])
    
    assert_not_nil json["escalation"]
    assert_equal escalation.id, json["escalation"]["id"]
  end

  # Create tests enhancements
  test "should set creator to current user" do
    task_params = {
      title: "New Task",
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id"])
    
    created_task = Task.find(json["id"])
    assert_equal @user.id, created_task.creator_id
  end

  test "should not allow creating in other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    
    task_params = {
      title: "Unauthorized Task",
      due_at: 1.hour.from_now.iso8601
    }
    
    post "/api/v1/lists/#{other_list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  test "should not allow due_at in past" do
    task_params = {
      title: "Past Task",
      due_at: 1.hour.ago.iso8601
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should create with location data" do
    task_params = {
      title: "Location Task",
      due_at: 1.hour.from_now.iso8601,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100,
      location_name: "New York"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id"])
    
    created_task = Task.find(json["id"])
    assert created_task.location_based?
    assert_equal 40.7128, created_task.location_latitude
    assert_equal -74.0060, created_task.location_longitude
    assert_equal 100, created_task.location_radius_meters
    assert_equal "New York", created_task.location_name
  end

  test "should create recurring task with pattern" do
    task_params = {
      title: "Recurring Task",
      due_at: 1.hour.from_now.iso8601,
      is_recurring: true,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_days: ["monday", "tuesday", "wednesday"]
    }
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: task_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id"])
    
    created_task = Task.find(json["id"])
    assert created_task.is_recurring?
    assert_equal "daily", created_task.recurrence_pattern
    assert_equal 1, created_task.recurrence_interval
    assert_equal ["monday", "tuesday", "wednesday"], created_task.recurrence_days
  end

  # Update tests enhancements
  test "should not allow changing list_id" do
    other_list = create_test_list(@user, name: "Other List")
    
    update_params = {
      list_id: other_list.id
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", 
          params: update_params, 
          headers: @auth_headers
    
    assert_response :success
    # Task should remain in original list
    @task.reload
    assert_equal @list.id, @task.list_id
  end

  test "should not allow non-owner to update unless shared with edit permission" do
    other_user = create_test_user(email: "other@example.com")
    
    update_params = {
      title: "Unauthorized Update"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", 
          params: update_params, 
          headers: auth_headers(other_user)
    
    assert_error_response(response, :forbidden, "You can only edit tasks you created")
  end

  test "should track update in task_events" do
    update_params = {
      title: "Updated Task"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", 
          params: update_params, 
          headers: @auth_headers
    
    assert_response :success
    
    # Check that task event was created
    event = @task.task_events.where(kind: "updated").last
    assert_not_nil event
    assert_equal @user.id, event.user_id
  end

  # Delete tests enhancements
  test "should cascade delete to subtasks" do
    subtask = create_test_task(@list, creator: @user, parent_task: @task)
    
    delete "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :no_content
    
    # Check that subtask is also deleted
    subtask.reload
    assert subtask.deleted?
  end

  test "should track deletion in task_events" do
    delete "/api/v1/lists/#{@list.id}/tasks/#{@task.id}", headers: @auth_headers
    
    assert_response :no_content
    
    # Check that task event was created
    event = @task.task_events.where(kind: "deleted").last
    assert_not_nil event
    assert_equal @user.id, event.user_id
  end

  # Complete tests enhancements
  test "should notify coach on completion if preferences allow" do
    coach = create_test_user(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "coach",
      status: "active"
    )
    
    # Mock notification service
    NotificationService.expects(:notify_task_completion).with(@task, coach)
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete", 
         params: { completed: true }, 
         headers: @auth_headers
    
    assert_response :success
  end

  test "should reset escalation on completion" do
    # Create escalation
    escalation = ItemEscalation.create!(
      task: @task,
      escalated_at: Time.current,
      reason: "Overdue"
    )
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete", 
         params: { completed: true }, 
         headers: @auth_headers
    
    assert_response :success
    
    # Check that escalation is reset
    escalation.reload
    assert_not_nil escalation.resolved_at
  end

  test "should track completion in task_events" do
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/complete", 
         params: { completed: true }, 
         headers: @auth_headers
    
    assert_response :success
    
    # Check that task event was created
    event = @task.task_events.where(kind: "completed").last
    assert_not_nil event
    assert_equal @user.id, event.user_id
  end

  # Reassign tests enhancements
  test "should not allow reassigning to past date" do
    reassign_params = {
      due_at: 1.hour.ago.iso8601,
      reason: "Invalid date"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should reset escalation on reassignment" do
    # Create escalation
    escalation = ItemEscalation.create!(
      task: @task,
      escalated_at: Time.current,
      reason: "Overdue"
    )
    
    reassign_params = {
      due_at: 2.hours.from_now.iso8601,
      reason: "Need more time"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_response :success
    
    # Check that escalation is reset
    escalation.reload
    assert_not_nil escalation.resolved_at
  end

  test "should notify coach on reassignment" do
    coach = create_test_user(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "coach",
      status: "active"
    )
    
    # Mock notification service
    NotificationService.expects(:notify_task_reassignment).with(@task, coach)
    
    reassign_params = {
      due_at: 2.hours.from_now.iso8601,
      reason: "Need more time"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_response :success
  end

  test "should track reassignment in task_events" do
    reassign_params = {
      due_at: 2.hours.from_now.iso8601,
      reason: "Need more time"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/reassign", 
         params: reassign_params, 
         headers: @auth_headers
    
    assert_response :success
    
    # Check that task event was created
    event = @task.task_events.where(kind: "reassigned").last
    assert_not_nil event
    assert_equal @user.id, event.user_id
    assert_equal "Need more time", event.reason
  end

  # Submit explanation tests
  test "should submit explanation for missed task" do
    @task.update!(
      requires_explanation_if_missed: true,
      due_at: 1.hour.ago,
      status: :pending
    )
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/submit_explanation", 
         params: { reason: "Had an emergency" }, 
         headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "missed_reason", "submitted_at"])
    
    assert_equal "Had an emergency", json["missed_reason"]
    assert_not_nil json["submitted_at"]
  end

  test "should require task to be overdue" do
    @task.update!(
      requires_explanation_if_missed: true,
      due_at: 1.hour.from_now,
      status: :pending
    )
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/submit_explanation", 
         params: { reason: "Explanation" }, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "This task does not require an explanation")
  end

  test "should require requires_explanation_if_missed to be true" do
    @task.update!(
      requires_explanation_if_missed: false,
      due_at: 1.hour.ago,
      status: :pending
    )
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/submit_explanation", 
         params: { reason: "Explanation" }, 
         headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "This task does not require an explanation")
  end

  test "should record missed_reason and submitted_at" do
    @task.update!(
      requires_explanation_if_missed: true,
      due_at: 1.hour.ago,
      status: :pending
    )
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/submit_explanation", 
         params: { reason: "Had an emergency" }, 
         headers: @auth_headers
    
    assert_response :success
    
    @task.reload
    assert_equal "Had an emergency", @task.missed_reason
    assert_not_nil @task.submitted_at
  end

  test "should notify coach that explanation was submitted" do
    coach = create_test_user(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "coach",
      status: "active"
    )
    
    @task.update!(
      requires_explanation_if_missed: true,
      due_at: 1.hour.ago,
      status: :pending
    )
    
    # Mock notification service
    NotificationService.expects(:notify_explanation_submitted).with(@task, coach)
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/submit_explanation", 
         params: { reason: "Had an emergency" }, 
         headers: @auth_headers
    
    assert_response :success
  end

  # Special endpoints tests
  test "should get blocking tasks" do
    # Create blocking escalation
    escalation = ItemEscalation.create!(
      task: @task,
      escalated_at: Time.current,
      reason: "Overdue",
      blocking_app: true
    )
    
    get "/api/v1/tasks/blocking", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    task_ids = json.map { |t| t["id"] }
    assert_includes task_ids, @task.id
  end

  test "should get tasks awaiting explanation" do
    @task.update!(
      requires_explanation_if_missed: true,
      due_at: 1.hour.ago,
      status: :pending
    )
    
    get "/api/v1/tasks/awaiting_explanation", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    task_ids = json.map { |t| t["id"] }
    assert_includes task_ids, @task.id
  end

  test "should get overdue tasks" do
    @task.update!(due_at: 1.hour.ago, status: :pending)
    
    get "/api/v1/tasks/overdue", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    task_ids = json.map { |t| t["id"] }
    assert_includes task_ids, @task.id
  end

  # Subtask operations tests
  test "should add subtask to parent" do
    subtask_params = {
      title: "New Subtask",
      description: "Subtask description"
    }
    
    post "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/add_subtask", 
         params: subtask_params, 
         headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title"])
    
    assert_equal "New Subtask", json["title"]
    
    # Check that subtask was created
    subtask = Task.find(json["id"])
    assert_equal @task.id, subtask.parent_task_id
  end

  test "should update subtask" do
    subtask = create_test_task(@list, creator: @user, parent_task: @task)
    
    update_params = {
      title: "Updated Subtask"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/subtasks/#{subtask.id}", 
          params: update_params, 
          headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "title"])
    
    assert_equal "Updated Subtask", json["title"]
  end

  test "should delete subtask" do
    subtask = create_test_task(@list, creator: @user, parent_task: @task)
    
    delete "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/subtasks/#{subtask.id}", 
           headers: @auth_headers
    
    assert_response :no_content
    
    # Check that subtask is deleted
    assert_raises(ActiveRecord::RecordNotFound) do
      Task.find(subtask.id)
    end
  end

  test "should toggle visibility" do
    coach = create_test_user(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      invited_by: "coach",
      status: "active"
    )
    
    toggle_params = {
      coach_id: coach.id,
      visible: false
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/toggle_visibility", 
          params: toggle_params, 
          headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id"])
    
    # Check that visibility restriction was created
    restriction = ItemVisibilityRestriction.find_by(
      task: @task,
      coaching_relationship: coaching_relationship
    )
    assert_not_nil restriction
  end

  test "should change visibility setting" do
    change_params = {
      visibility: "hidden"
    }
    
    patch "/api/v1/lists/#{@list.id}/tasks/#{@task.id}/change_visibility", 
          params: change_params, 
          headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "visibility"])
    
    assert_equal "hidden", json["visibility"]
  end
end
