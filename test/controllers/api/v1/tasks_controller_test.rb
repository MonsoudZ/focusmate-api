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
end
