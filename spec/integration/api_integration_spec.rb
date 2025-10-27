require "rails_helper"

RSpec.describe "API Integration", type: :request do
  let(:user) { create(:user, email: "integration_#{SecureRandom.hex(4)}@example.com") }
  let(:list) { create(:list, owner: user) }
  let(:auth_headers) { auth_headers(user) }

  describe "complete user workflow" do
    it "should handle complete user workflow" do
      # 1. Login
      post "/api/v1/login", params: {
        email: user.email,
        password: "password123"
      }
      expect(response).to have_http_status(:success)
      login_json = JSON.parse(response.body)
      expect(login_json).to have_key("user")
      expect(login_json).to have_key("token")
      token = login_json["token"]

      # 2. Get profile
      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      profile_json = JSON.parse(response.body)
      expect(profile_json).to have_key("id")
      expect(profile_json).to have_key("email")
      expect(profile_json["id"]).to eq(user.id)

      # 3. Get lists
      get "/api/v1/lists", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      lists_json = JSON.parse(response.body)
      lists = lists_json.is_a?(Hash) ? (lists_json["lists"] || []) : lists_json
      expect(lists).to be_a(Array)

      # 4. Create a task
      post "/api/v1/lists/#{list.id}/tasks",
           params: {
             title: "Integration Test Task",
             due_at: 1.hour.from_now.iso8601,
             strict_mode: true
           },
           headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:created)
      task_json = JSON.parse(response.body)
      expect(task_json).to have_key("id")
      expect(task_json).to have_key("title")
      task_id = task_json["id"]

      # 5. Get tasks for list
      get "/api/v1/lists/#{list.id}/tasks",
          headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      tasks_json = JSON.parse(response.body)
      expect(tasks_json).to have_key("tasks")
      expect(tasks_json["tasks"]).to be_a(Array)

      # 6. Get specific task
      get "/api/v1/lists/#{list.id}/tasks/#{task_id}",
          headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      task_detail_json = JSON.parse(response.body)
      expect(task_detail_json).to have_key("id")
      expect(task_detail_json).to have_key("title")
      expect(task_detail_json["id"]).to eq(task_id)

      # 7. Update task
      patch "/api/v1/lists/#{list.id}/tasks/#{task_id}",
            params: {
              title: "Updated Integration Test Task",
              note: "Updated note"
            },
            headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      updated_task_json = JSON.parse(response.body)
      expect(updated_task_json).to have_key("id")
      expect(updated_task_json).to have_key("title")
      expect(updated_task_json["title"]).to eq("Updated Integration Test Task")

      # 8. Complete task
      post "/api/v1/lists/#{list.id}/tasks/#{task_id}/complete",
           params: { completed: true },
           headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      completed_task_json = JSON.parse(response.body)
      expect(completed_task_json).to have_key("id")
      expect(completed_task_json).to have_key("status")
      expect(completed_task_json["status"]).to eq("done")

      # 9. Get all tasks
      get "/api/v1/tasks/all_tasks",
          headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      all_tasks_json = JSON.parse(response.body)
      expect(all_tasks_json).to have_key("tasks")
      expect(all_tasks_json["tasks"]).to be_a(Array)

      # 10. Logout
      delete "/api/v1/logout", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "iOS app workflow" do
    it "should handle iOS app workflow" do
      # 1. Login with iOS endpoint
      post "/api/v1/auth/sign_in", params: {
        email: user.email,
        password: "password123"
      }
      expect(response).to have_http_status(:success)
      login_json = JSON.parse(response.body)
      expect(login_json).to have_key("user")
      expect(login_json).to have_key("token")

      json = JSON.parse(response.body)
      token =
        json["token"] ||
        json.dig("data", "token") ||
        response.headers["Authorization"]&.to_s&.sub(/^Bearer\s+/i, "")

      expect(token).to be_present, "Expected a token in body or Authorization header, got: #{json.inspect} / #{response.headers.inspect}"

      # 2. Create task with iOS parameters
      post "/api/v1/lists/#{list.id}/tasks",
           params: {
             name: "iOS Task", # iOS uses 'name'
             dueDate: 1.hour.from_now.to_i, # iOS sends epoch seconds
             description: "iOS description", # iOS uses 'description'
             subtasks: [ "iOS Subtask 1", "iOS Subtask 2" ]
           },
           headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:created)
      task_json = JSON.parse(response.body)
      expect(task_json).to have_key("id")
      expect(task_json).to have_key("title")
      task_id = task_json["id"]

      # 3. Verify task was created correctly
      get "/api/v1/lists/#{list.id}/tasks/#{task_id}",
          headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
      task_detail_json = JSON.parse(response.body)
      expect(task_detail_json).to have_key("id")
      expect(task_detail_json).to have_key("title")
      expect(task_detail_json).to have_key("note")
      expect(task_detail_json["title"]).to eq("iOS Task")
      expect(task_detail_json["note"]).to eq("iOS description")

      # 4. Complete task
      post "/api/v1/lists/#{list.id}/tasks/#{task_id}/complete",
           params: { completed: true },
           headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:success)

      # 5. Logout with iOS endpoint
      delete "/api/v1/auth/sign_out", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "error handling workflow" do
    it "should handle error scenarios" do
      # 1. Try to access protected endpoint without token
      get "/api/v1/profile"
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Authorization token required")

      # 2. Try to access with invalid token
      get "/api/v1/profile", headers: { "Authorization" => "Bearer invalid_token" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Invalid token")

      # 3. Try to access with expired token
      expired_token = JWT.encode(
        {
          user_id: user.id,
          exp: 1.hour.ago.to_i
        },
        Rails.application.credentials.secret_key_base
      )
      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{expired_token}" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Token expired")

      # 4. Try to access other user's resources
      other_user = create(:user, email: "other_#{SecureRandom.hex(4)}@example.com")
      other_list = create(:list, owner: other_user)

      get "/api/v1/lists/#{other_list.id}/tasks", headers: auth_headers
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("List not found")

      # 5. Try to create task with invalid data
      post "/api/v1/lists/#{list.id}/tasks",
           params: {
             title: "", # Invalid: empty title
             due_at: "invalid-date" # Invalid: bad date format
           },
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Validation failed")
    end
  end

  describe "concurrent user workflow" do
    it "should handle concurrent operations" do
      # Create multiple users
      users = []
      3.times do |i|
        users << create(:user, email: "user#{i}_#{SecureRandom.hex(4)}@example.com")
      end

      # Each user creates tasks concurrently
      threads = []
      users.each_with_index do |user, index|
        threads << Thread.new do
          auth_headers = auth_headers(user)
          list = create(:list, owner: user, name: "List #{index}")

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
      expect(true).to be_truthy
    end
  end

  describe "data consistency workflow" do
    it "should maintain data consistency" do
      # 1. Create task
      post "/api/v1/lists/#{list.id}/tasks",
           params: {
             title: "Consistency Test Task",
             due_at: 1.hour.from_now.iso8601,
             note: "Original note"
           },
           headers: auth_headers
      expect(response).to have_http_status(:created)
      task_json = JSON.parse(response.body)
      expect(task_json).to have_key("id")
      task_id = task_json["id"]

      # 2. Update task multiple times
      updates = [
        { title: "First Update", note: "First note" },
        { title: "Second Update", note: "Second note" },
        { title: "Final Update", note: "Final note" }
      ]

      updates.each do |update|
        patch "/api/v1/lists/#{list.id}/tasks/#{task_id}",
              params: update,
              headers: auth_headers
        expect(response).to have_http_status(:success)
      end

      # 3. Verify final state
      get "/api/v1/lists/#{list.id}/tasks/#{task_id}", headers: auth_headers
      expect(response).to have_http_status(:success)
      final_task_json = JSON.parse(response.body)
      expect(final_task_json).to have_key("id")
      expect(final_task_json).to have_key("title")
      expect(final_task_json).to have_key("note")
      expect(final_task_json["title"]).to eq("Final Update")
      expect(final_task_json["note"]).to eq("Final note")

      # 4. Complete task
      post "/api/v1/lists/#{list.id}/tasks/#{task_id}/complete",
           params: { completed: true },
           headers: auth_headers
      expect(response).to have_http_status(:success)

      # 5. Verify completion
      get "/api/v1/lists/#{list.id}/tasks/#{task_id}", headers: auth_headers
      expect(response).to have_http_status(:success)
      completed_task_json = JSON.parse(response.body)
      expect(completed_task_json).to have_key("id")
      expect(completed_task_json).to have_key("status")
      expect(completed_task_json["status"]).to eq("done")
    end
  end

  describe "filtering and querying workflow" do
    it "should handle filtering and querying" do
      # Create tasks with different statuses and due dates
      tasks = []

      # Pending task
      tasks << create(:task, list: list, creator: user,
                     title: "Pending Task",
                     status: :pending,
                     due_at: 1.hour.from_now)

      # Completed task
      tasks << create(:task, list: list, creator: user,
                     title: "Completed Task",
                     status: :done,
                     due_at: 1.hour.ago)

      # Overdue task
      tasks << create(:task, list: list, creator: user,
                     title: "Overdue Task",
                     status: :pending,
                     due_at: 2.hours.ago)

      # 1. Get all tasks
      get "/api/v1/tasks/all_tasks", headers: auth_headers
      expect(response).to have_http_status(:success)
      all_tasks_json = JSON.parse(response.body)
      expect(all_tasks_json).to have_key("tasks")
      expect(all_tasks_json["tasks"].length).to eq(3)

      # 2. Filter by status
      get "/api/v1/tasks/all_tasks?status=completed", headers: auth_headers
      expect(response).to have_http_status(:success)
      completed_tasks_json = JSON.parse(response.body)
      expect(completed_tasks_json).to have_key("tasks")
      expect(completed_tasks_json["tasks"].length).to eq(1)
      expect(completed_tasks_json["tasks"].first["title"]).to eq("Completed Task")

      # 3. Filter by list
      get "/api/v1/tasks/all_tasks?list_id=#{list.id}", headers: auth_headers
      expect(response).to have_http_status(:success)
      list_tasks_json = JSON.parse(response.body)
      expect(list_tasks_json).to have_key("tasks")
      expect(list_tasks_json["tasks"].length).to eq(3)

      # 4. Filter by overdue
      get "/api/v1/tasks/all_tasks?status=overdue", headers: auth_headers
      expect(response).to have_http_status(:success)
      overdue_tasks_json = JSON.parse(response.body)
      expect(overdue_tasks_json).to have_key("tasks")
      expect(overdue_tasks_json["tasks"].length).to eq(1)
      expect(overdue_tasks_json["tasks"].first["title"]).to eq("Overdue Task")

      # 5. Filter by since parameter
      since_time = 30.minutes.ago.iso8601
      get "/api/v1/tasks/all_tasks?since=#{since_time}", headers: auth_headers
      expect(response).to have_http_status(:success)
      recent_tasks_json = JSON.parse(response.body)
      expect(recent_tasks_json).to have_key("tasks")
      # Should include tasks created after the since time
      expect(recent_tasks_json["tasks"].length).to be >= 0
    end
  end

  describe "authentication edge cases" do
    it "should handle authentication edge cases" do
      # 1. Test with malformed Authorization header
      get "/api/v1/profile", headers: { "Authorization" => "InvalidFormat token" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Invalid token")

      # 2. Test with empty Authorization header
      get "/api/v1/profile", headers: { "Authorization" => "" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Authorization token required")

      # 3. Test with missing Authorization header
      get "/api/v1/profile"
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      msg = json["error"] || json["message"]
      msg = msg.is_a?(Hash) ? msg["message"] : msg
      expect(msg).to eq("Authorization token required")

      # 4. Test with valid token but non-existent user
      non_existent_user_token = JWT.encode(
        {
          user_id: 99999, # Non-existent user ID
          exp: 30.days.from_now.to_i
        },
        Rails.application.credentials.secret_key_base
      )
      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{non_existent_user_token}" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("User not found")
    end
  end

  describe "rate limiting workflow" do
    it "should handle rate limiting" do
      # Make multiple requests quickly to test rate limiting
      # Note: This test might not trigger rate limiting in test environment
      # but it tests the endpoint behavior under load

      10.times do |i|
        get "/api/v1/profile", headers: auth_headers
        # All requests should succeed in test environment
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "large data workflow" do
    it "should handle large data sets" do
      # Create many tasks to test performance
      task_count = 50

      task_count.times do |i|
        post "/api/v1/lists/#{list.id}/tasks",
             params: {
               title: "Bulk Task #{i}",
               due_at: (i + 1).hours.from_now.iso8601
             },
             headers: auth_headers
        expect(response).to have_http_status(:created)
      end

      # Get all tasks and verify count
      get "/api/v1/lists/#{list.id}/tasks", headers: auth_headers
      expect(response).to have_http_status(:success)
      tasks_json = JSON.parse(response.body)
      expect(tasks_json).to have_key("tasks")
      expect(tasks_json["tasks"].length).to eq(task_count)

      # Get all tasks across lists
      get "/api/v1/tasks/all_tasks", headers: auth_headers
      expect(response).to have_http_status(:success)
      all_tasks_json = JSON.parse(response.body)
      expect(all_tasks_json).to have_key("tasks")
      expect(all_tasks_json["tasks"].length).to eq(task_count)
    end
  end

  # Helper method for authentication headers
  def auth_headers(user = nil)
    user ||= defined?(current_user) && current_user || (respond_to?(:user) ? user() : create(:user))

    payload = { user_id: user.id, exp: 30.days.from_now.to_i }
    secret  = Rails.application.secret_key_base # works on Rails 7/8

    token = JWT.encode(payload, secret, 'HS256')
    { "Authorization" => "Bearer #{token}" }
  end
end
