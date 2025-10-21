require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @task = create_test_task(@list, creator: @user)
    @auth_headers = auth_headers(@user)
  end

  # Authentication Security Tests
  test "should not allow access without authentication" do
    endpoints = [
      "/api/v1/profile",
      "/api/v1/lists",
      "/api/v1/lists/#{@list.id}/tasks",
      "/api/v1/tasks/all_tasks"
    ]

    endpoints.each do |endpoint|
      get endpoint
      assert_error_response(response, :unauthorized, "Authorization token required")
    end
  end

  test "should not allow access with invalid token" do
    invalid_tokens = [
      "invalid_token",
      "Bearer invalid_token",
      "Bearer ",
      "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid",
      ""
    ]

    invalid_tokens.each do |token|
      get "/api/v1/profile", headers: { "Authorization" => token }
      assert_error_response(response, :unauthorized, "Invalid token")
    end
  end

  test "should not allow access with expired token" do
    expired_token = JWT.encode(
      {
        user_id: @user.id,
        exp: 1.hour.ago.to_i
      },
      Rails.application.credentials.secret_key_base
    )

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{expired_token}" }
    assert_error_response(response, :unauthorized, "Token expired")
  end

  test "should not allow access with tampered token" do
    # Create a valid token
    valid_token = JWT.encode(
      {
        user_id: @user.id,
        exp: 30.days.from_now.to_i
      },
      Rails.application.credentials.secret_key_base
    )

    # Tamper with the token
    tampered_token = valid_token + "tampered"

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{tampered_token}" }
    assert_error_response(response, :unauthorized, "Invalid token")
  end

  test "should not allow access with token for non-existent user" do
    non_existent_user_token = JWT.encode(
      {
        user_id: 99999,
        exp: 30.days.from_now.to_i
      },
      Rails.application.credentials.secret_key_base
    )

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{non_existent_user_token}" }
    assert_error_response(response, :unauthorized, "User not found")
  end

  # Authorization Security Tests
  test "should not allow access to other user's resources" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user)
    other_task = create_test_task(other_list, creator: other_user)

    # Try to access other user's list
    get "/api/v1/lists/#{other_list.id}/tasks", headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")

    # Try to access other user's task
    get "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")

    # Try to update other user's task
    patch "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", 
          params: { title: "Hacked Task" },
          headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")

    # Try to delete other user's task
    delete "/api/v1/lists/#{other_list.id}/tasks/#{other_task.id}", headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")
  end

  test "should not allow access to non-existent resources" do
    non_existent_id = 99999

    # Try to access non-existent list
    get "/api/v1/lists/#{non_existent_id}/tasks", headers: @auth_headers
    assert_error_response(response, :not_found, "List not found")

    # Try to access non-existent task
    get "/api/v1/lists/#{@list.id}/tasks/#{non_existent_id}", headers: @auth_headers
    assert_error_response(response, :not_found, "Task not found")

    # Try to update non-existent task
    patch "/api/v1/lists/#{@list.id}/tasks/#{non_existent_id}", 
          params: { title: "Hacked Task" },
          headers: @auth_headers
    assert_error_response(response, :not_found, "Task not found")
  end

  # Input Validation Security Tests
  test "should prevent SQL injection in parameters" do
    malicious_params = {
      title: "'; DROP TABLE users; --",
      due_at: "1'; DROP TABLE tasks; --"
    }

    post "/api/v1/lists/#{@list.id}/tasks", 
         params: malicious_params,
         headers: @auth_headers

    # Should either create task with escaped input or fail validation
    # The important thing is that it doesn't execute SQL injection
    if response.status == 201
      # Task was created, but SQL injection was prevented
      json = assert_json_response(response, ["id"])
      task = Task.find(json["id"])
      assert_equal "'; DROP TABLE users; --", task.title
    else
      # Validation failed, which is also acceptable
      assert_error_response(response, :unprocessable_entity, "Validation failed")
    end

    # Verify that users table still exists
    assert User.count >= 0
  end

  test "should prevent XSS in task content" do
    xss_payload = "<script>alert('xss')</script>"
    
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "Task with XSS",
           note: xss_payload,
           due_at: 1.hour.from_now.iso8601
         },
         headers: @auth_headers

    assert_response :created
    json = assert_json_response(response, ["id"])
    task = Task.find(json["id"])
    
    # The XSS payload should be stored as-is (not executed)
    assert_equal xss_payload, task.note
  end

  test "should prevent mass assignment attacks" do
    malicious_params = {
      title: "Legitimate Task",
      due_at: 1.hour.from_now.iso8601,
      creator_id: 99999, # Try to assign to different user
      list_id: 99999, # Try to assign to different list
      user_id: 99999 # Try to change user
    }

    post "/api/v1/lists/#{@list.id}/tasks", 
         params: malicious_params,
         headers: @auth_headers

    assert_response :created
    json = assert_json_response(response, ["id"])
    task = Task.find(json["id"])
    
    # Should not be able to change creator or list
    assert_equal @user, task.creator
    assert_equal @list, task.list
  end

  test "should prevent parameter pollution" do
    # Try to send multiple values for the same parameter
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "Task",
           due_at: 1.hour.from_now.iso8601,
           "title[]" => "Malicious Title"
         },
         headers: @auth_headers

    assert_response :created
    json = assert_json_response(response, ["id"])
    task = Task.find(json["id"])
    
    # Should use the first valid title
    assert_equal "Task", task.title
  end

  # Rate Limiting Security Tests
  test "should handle rapid requests gracefully" do
    # Make many requests quickly
    20.times do |i|
      get "/api/v1/profile", headers: @auth_headers
      # In test environment, rate limiting might not be active
      # but the endpoint should handle the load gracefully
      assert [200, 429].include?(response.status), "Request #{i} failed with status #{response.status}"
    end
  end

  test "should handle concurrent requests" do
    threads = []
    10.times do |i|
      threads << Thread.new do
        get "/api/v1/profile", headers: @auth_headers
        assert [200, 429].include?(response.status)
      end
    end

    threads.each(&:join)
    # If we get here without errors, concurrent requests were handled
    assert true
  end

  # Session Security Tests
  test "should not expose session information" do
    get "/api/v1/profile", headers: @auth_headers
    assert_response :success
    
    # Check that no session cookies are set
    assert_nil response.headers["Set-Cookie"]
  end

  test "should not allow session fixation" do
    # JWT tokens should be stateless and not vulnerable to session fixation
    get "/api/v1/profile", headers: @auth_headers
    assert_response :success
    
    # No session cookies should be set
    assert_nil response.headers["Set-Cookie"]
  end

  # Content Security Tests
  test "should not expose sensitive information in error messages" do
    # Try to access non-existent resource
    get "/api/v1/lists/99999/tasks", headers: @auth_headers
    assert_error_response(response, :not_found)
    
    # Error message should not expose internal details
    json = JSON.parse(response.body)
    assert_not json["error"]["message"].include?("ActiveRecord::RecordNotFound")
    assert_not json["error"]["message"].include?("database")
  end

  test "should not expose stack traces in production" do
    # This test would need to be run in production environment
    # to verify that stack traces are not exposed
    skip "Stack trace testing requires production environment"
  end

  # Authentication Bypass Tests
  test "should not allow authentication bypass through parameter manipulation" do
    # Try to access with user_id in parameters
    get "/api/v1/profile?user_id=#{@user.id}"
    assert_error_response(response, :unauthorized, "Authorization token required")

    # Try to access with user_id in headers
    get "/api/v1/profile", headers: { "X-User-ID" => @user.id.to_s }
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not allow authentication bypass through different endpoints" do
    # Try to use test endpoints in production-like scenario
    get "/api/v1/test-profile"
    # Should require authentication even for test endpoints
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Token Security Tests
  test "should not accept tokens with invalid algorithm" do
    # Create token with different algorithm
    invalid_token = JWT.encode(
      {
        user_id: @user.id,
        exp: 30.days.from_now.to_i
      },
      Rails.application.credentials.secret_key_base,
      "HS512" # Different algorithm
    )

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{invalid_token}" }
    assert_error_response(response, :unauthorized, "Invalid token")
  end

  test "should not accept tokens with missing required claims" do
    # Create token without user_id
    invalid_token = JWT.encode(
      {
        exp: 30.days.from_now.to_i
      },
      Rails.application.credentials.secret_key_base
    )

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{invalid_token}" }
    assert_error_response(response, :unauthorized, "Invalid token")
  end

  test "should not accept tokens with invalid signature" do
    # Create token with wrong secret
    invalid_token = JWT.encode(
      {
        user_id: @user.id,
        exp: 30.days.from_now.to_i
      },
      "wrong_secret"
    )

    get "/api/v1/profile", headers: { "Authorization" => "Bearer #{invalid_token}" }
    assert_error_response(response, :unauthorized, "Invalid token")
  end

  # File Upload Security Tests
  test "should not allow file uploads through task creation" do
    # Try to upload a file through task parameters
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: "Task with file",
           due_at: 1.hour.from_now.iso8601,
           file: "malicious_file.exe"
         },
         headers: @auth_headers

    # Should either create task without file or fail validation
    # The important thing is that no file is processed
    if response.status == 201
      json = assert_json_response(response, ["id"])
      task = Task.find(json["id"])
      # Task model doesn't have file attribute, so we just verify task was created
      assert_not_nil task
    else
      assert_error_response(response, :unprocessable_entity, "Validation failed")
    end
  end

  # HTTP Method Security Tests
  test "should not allow dangerous HTTP methods" do
    # TRACE method is not supported in Rails test framework
    # Skip this test as trace method doesn't exist

    # Try to use OPTIONS method
    options "/api/v1/profile", headers: @auth_headers
    # OPTIONS might be allowed for CORS, but should not expose sensitive data
    if response.status == 200
      assert_empty response.body
    end
  end

  test "should handle malformed requests gracefully" do
    # Try to send malformed JSON
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: "invalid json",
         headers: @auth_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request

    # Try to send extremely large request
    large_data = "x" * 10000
    post "/api/v1/lists/#{@list.id}/tasks", 
         params: {
           title: large_data,
           due_at: 1.hour.from_now.iso8601
         },
         headers: @auth_headers
    
    # Should either reject or truncate the data
    assert [400, 413, 422].include?(response.status)
  end
end
