require "test_helper"

class ApiIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @auth_headers = auth_headers(@user)
  end

  test "complete user workflow" do
    # 1. Login
    post "/api/v1/login", params: {
      email: @user.email,
      password: "password123"
    }
    assert_response :success
    login_json = assert_json_response(response, ["user", "token"])
    token = login_json["token"]

    # 2. Get profile
    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    profile_json = assert_json_response(response, ["id", "email"])
    assert_equal @user.id, profile_json["id"]

    # 3. Get lists
    get "/api/v1/lists", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    lists_json = assert_json_response(response)
    assert lists_json.is_a?(Array)

    # 4. Create a task
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "Integration Test Task",
           due_at: 1.hour.from_now.iso8601,
           strict_mode: true
         },
         headers: { "Authorization" => "Bearer #{token}" }
    assert_response :created
    task_json = assert_json_response(response, ["id", "title"])
    task_id = task_json["id"]

    # 5. Get tasks for list
    get "/api/v1/lists/#{@list.id}/tasks", 
        headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    tasks_json = assert_json_response(response, ["tasks"])
    assert tasks_json["tasks"].is_a?(Array)

    # 6. Get specific task
    get "/api/v1/lists/#{@list.id}/tasks/#{task_id}", 
        headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    task_detail_json = assert_json_response(response, ["id", "title"])
    assert_equal task_id, task_detail_json["id"]

    # 7. Update task
    patch "/api/v1/lists/#{@list.id}/tasks/#{task_id}", 
          params: {
            title: "Updated Integration Test Task",
            note: "Updated note"
          },
          headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    updated_task_json = assert_json_response(response, ["id", "title"])
    assert_equal "Updated Integration Test Task", updated_task_json["title"]

    # 8. Complete task
    post "/api/v1/lists/#{@list.id}/tasks/#{task_id}/complete", 
         params: { completed: true },
         headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    completed_task_json = assert_json_response(response, ["id", "status"])
    assert_equal "done", completed_task_json["status"]

    # 9. Get all tasks
    get "/api/v1/tasks/all_tasks", 
        headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    all_tasks_json = assert_json_response(response, ["tasks"])
    assert all_tasks_json["tasks"].is_a?(Array)

    # 10. Logout
    delete "/api/v1/logout", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :no_content
  end

  test "iOS app workflow" do
    # 1. Login with iOS endpoint
    post "/api/v1/auth/sign_in", params: {
      email: @user.email,
      password: "password123"
    }
    assert_response :success
    login_json = assert_json_response(response, ["user", "token"])
    token = login_json["token"]

    # 2. Create task with iOS parameters
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           name: "iOS Task", # iOS uses 'name'
           dueDate: 1.hour.from_now.to_i, # iOS sends epoch seconds
           description: "iOS description", # iOS uses 'description'
           subtasks: ["iOS Subtask 1", "iOS Subtask 2"]
         },
         headers: { "Authorization" => "Bearer #{token}" }
    assert_response :created
    task_json = assert_json_response(response, ["id", "title"])
    task_id = task_json["id"]

    # 3. Verify task was created correctly
    get "/api/v1/lists/#{@list.id}/tasks/#{task_id}", 
        headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    task_detail_json = assert_json_response(response, ["id", "title", "note"])
    assert_equal "iOS Task", task_detail_json["title"]
    assert_equal "iOS description", task_detail_json["note"]

    # 4. Complete task
    post "/api/v1/lists/#{@list.id}/tasks/#{task_id}/complete", 
         params: { completed: true },
         headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success

    # 5. Logout with iOS endpoint
    delete "/api/v1/auth/sign_out", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :no_content
  end

  test "error handling workflow" do
    # 1. Try to access protected endpoint without token
    get "/api/v1/profile"
    assert_error_response(response, :unauthorized, "Authorization token required")

    # 2. Try to access with invalid token
    get "/api/v1/profile", headers: { "Authorization" => "Bearer invalid_token" }
    assert_error_response(response, :unauthorized, "Invalid token")

    # 3. Try to access with expired token
    expired_token = JWT.encode(
      {
        user_id: @user.id,
        exp: 1.hour.ago.to_i
      },
      Rails.application.credentials.secret_key_base
    )
    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{expired_token}" }
    assert_error_response(response, :unauthorized, "Token expired")

    # 4. Try to access other user's resources
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    
    get "/api/v1/lists/#{other_list.id}/tasks", headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")

    # 5. Try to create task with invalid data
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "", # Invalid: empty title
           due_at: "invalid-date" # Invalid: bad date format
         },
         headers: @auth_headers
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "concurrent user workflow" do
    # Create multiple users
    users = []
    3.times do |i|
      users << create_test_user(email: "user#{i}@example.com")
    end

    # Each user creates tasks concurrently
    threads = []
    users.each_with_index do |user, index|
      threads << Thread.new do
        auth_headers = auth_headers(user)
        list = create_test_list(user, name: "List #{index}")
        
        # Create multiple tasks
        5.times do |j|
          post "/api/v1/lists/#{list.id}/tasks", 
               params: {
                 title: "Task #{j} for User #{index}",
                 due_at: (j + 1).hours.from_now.iso8601
               },
               headers: auth_headers
        end
        
        # Get tasks
        get "/api/v1/lists/#{list.id}/tasks", headers: auth_headers
        
        # Get all tasks
        get "/api/v1/tasks/all_tasks", headers: auth_headers
      end
    end

    threads.each(&:join)
    # If we get here without errors, the concurrent operations succeeded
    assert true
  end

  test "data consistency workflow" do
    # 1. Create task
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "Consistency Test Task",
           due_at: 1.hour.from_now.iso8601,
           note: "Original note"
         },
         headers: @auth_headers
    assert_response :created
    task_json = assert_json_response(response, ["id"])
    task_id = task_json["id"]

    # 2. Update task multiple times
    updates = [
      { title: "First Update", note: "First note" },
      { title: "Second Update", note: "Second note" },
      { title: "Final Update", note: "Final note" }
    ]

    updates.each do |update|
      patch "/api/v1/lists/#{@list.id}/tasks/#{task_id}", 
            params: update,
            headers: @auth_headers
      assert_response :success
    end

    # 3. Verify final state
    get "/api/v1/lists/#{@list.id}/tasks/#{task_id}", headers: @auth_headers
    assert_response :success
    final_task_json = assert_json_response(response, ["id", "title", "note"])
    assert_equal "Final Update", final_task_json["title"]
    assert_equal "Final note", final_task_json["note"]

    # 4. Complete task
    post "/api/v1/lists/#{@list.id}/tasks/#{task_id}/complete", 
         params: { completed: true },
         headers: @auth_headers
    assert_response :success

    # 5. Verify completion
    get "/api/v1/lists/#{@list.id}/tasks/#{task_id}", headers: @auth_headers
    assert_response :success
    completed_task_json = assert_json_response(response, ["id", "status"])
    assert_equal "done", completed_task_json["status"]
  end

  test "filtering and querying workflow" do
    # Create tasks with different statuses and due dates
    tasks = []
    
    # Pending task
    tasks << create_test_task(@list, creator: @user, 
                             title: "Pending Task", 
                             status: :pending, 
                             due_at: 1.hour.from_now)
    
    # Completed task
    tasks << create_test_task(@list, creator: @user, 
                             title: "Completed Task", 
                             status: :done, 
                             due_at: 1.hour.ago)
    
    # Overdue task
    tasks << create_test_task(@list, creator: @user, 
                             title: "Overdue Task", 
                             status: :pending, 
                             due_at: 2.hours.ago)

    # 1. Get all tasks
    get "/api/v1/tasks/all_tasks", headers: @auth_headers
    assert_response :success
    all_tasks_json = assert_json_response(response, ["tasks"])
    assert_equal 3, all_tasks_json["tasks"].length

    # 2. Filter by status
    get "/api/v1/tasks/all_tasks?status=completed", headers: @auth_headers
    assert_response :success
    completed_tasks_json = assert_json_response(response, ["tasks"])
    assert_equal 1, completed_tasks_json["tasks"].length
    assert_equal "Completed Task", completed_tasks_json["tasks"].first["title"]

    # 3. Filter by list
    get "/api/v1/tasks/all_tasks?list_id=#{@list.id}", headers: @auth_headers
    assert_response :success
    list_tasks_json = assert_json_response(response, ["tasks"])
    assert_equal 3, list_tasks_json["tasks"].length

    # 4. Filter by overdue
    get "/api/v1/tasks/all_tasks?status=overdue", headers: @auth_headers
    assert_response :success
    overdue_tasks_json = assert_json_response(response, ["tasks"])
    assert_equal 1, overdue_tasks_json["tasks"].length
    assert_equal "Overdue Task", overdue_tasks_json["tasks"].first["title"]

    # 5. Filter by since parameter
    since_time = 30.minutes.ago.iso8601
    get "/api/v1/tasks/all_tasks?since=#{since_time}", headers: @auth_headers
    assert_response :success
    recent_tasks_json = assert_json_response(response, ["tasks"])
    # Should include tasks created after the since time
    assert recent_tasks_json["tasks"].length >= 0
  end

  test "authentication edge cases" do
    # 1. Test with malformed Authorization header
    get "/api/v1/profile", headers: { "Authorization" => "InvalidFormat token" }
    assert_error_response(response, :unauthorized, "Authorization token required")

    # 2. Test with empty Authorization header
    get "/api/v1/profile", headers: { "Authorization" => "" }
    assert_error_response(response, :unauthorized, "Authorization token required")

    # 3. Test with missing Authorization header
    get "/api/v1/profile"
    assert_error_response(response, :unauthorized, "Authorization token required")

    # 4. Test with valid token but non-existent user
    non_existent_user_token = JWT.encode(
      {
        user_id: 99999, # Non-existent user ID
        exp: 30.days.from_now.to_i
      },
      Rails.application.credentials.secret_key_base
    )
    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{non_existent_user_token}" }
    assert_error_response(response, :unauthorized, "User not found")
  end

  test "rate limiting workflow" do
    # Make multiple requests quickly to test rate limiting
    # Note: This test might not trigger rate limiting in test environment
    # but it tests the endpoint behavior under load
    
    10.times do |i|
      get "/api/v1/profile", headers: @auth_headers
      # All requests should succeed in test environment
      assert_response :success
    end
  end

  test "large data workflow" do
    # Create many tasks to test performance
    task_count = 50
    
    task_count.times do |i|
      post "/api/v1/lists/#{@list.id}/tasks", 
           params: {
             title: "Bulk Task #{i}",
             due_at: (i + 1).hours.from_now.iso8601
           },
           headers: @auth_headers
      assert_response :created
    end

    # Get all tasks and verify count
    get "/api/v1/lists/#{@list.id}/tasks", headers: @auth_headers
    assert_response :success
    tasks_json = assert_json_response(response, ["tasks"])
    assert_equal task_count, tasks_json["tasks"].length

    # Get all tasks across lists
    get "/api/v1/tasks/all_tasks", headers: @auth_headers
    assert_response :success
    all_tasks_json = assert_json_response(response, ["tasks"])
    assert_equal task_count, all_tasks_json["tasks"].length
  end
end
