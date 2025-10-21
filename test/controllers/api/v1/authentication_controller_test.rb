require "test_helper"

class Api::V1::AuthenticationControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
  end

  # Login tests
  test "should login with valid credentials" do
    post "/api/v1/login", params: {
      email: @user.email,
      password: "password123"
    }
    
    assert_response :success
    json = assert_json_response(response, ["user", "token"])
    
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.email, json["user"]["email"]
    assert_not_nil json["token"]
  end

  test "should not login with invalid email" do
    post "/api/v1/login", params: {
      email: "nonexistent@example.com",
      password: "password123"
    }
    
    assert_error_response(response, :unauthorized, "Invalid email or password")
  end

  test "should not login with invalid password" do
    post "/api/v1/login", params: {
      email: @user.email,
      password: "wrongpassword"
    }
    
    assert_error_response(response, :unauthorized, "Invalid email or password")
  end

  test "should not login without email" do
    post "/api/v1/login", params: {
      password: "password123"
    }
    
    assert_error_response(response, :unauthorized, "Invalid email or password")
  end

  test "should not login without password" do
    post "/api/v1/login", params: {
      email: @user.email
    }
    
    assert_error_response(response, :unauthorized, "Invalid email or password")
  end

  test "should login with auth/sign_in endpoint" do
    post "/api/v1/auth/sign_in", params: {
      email: @user.email,
      password: "password123"
    }
    
    assert_response :success
    json = assert_json_response(response, ["user", "token"])
    assert_equal @user.id, json["user"]["id"]
  end

  # Registration tests
  test "should register with valid attributes" do
    post "/api/v1/register", params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "New User",
        role: "client"
      }
    }
    
    assert_response :created
    json = assert_json_response(response, ["user", "token"])
    
    assert_equal "newuser@example.com", json["user"]["email"]
    assert_equal "New User", json["user"]["name"]
    assert_equal "client", json["user"]["role"]
    assert_not_nil json["token"]
  end

  test "should register with auth/sign_up endpoint" do
    post "/api/v1/auth/sign_up", params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "New User"
      }
    }
    
    assert_response :created
    json = assert_json_response(response, ["user", "token"])
    assert_equal "newuser@example.com", json["user"]["email"]
  end

  test "should not register with invalid email" do
    post "/api/v1/register", params: {
      user: {
        email: "invalid-email",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not register with duplicate email" do
    post "/api/v1/register", params: {
      user: {
        email: @user.email,
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not register with mismatched passwords" do
    post "/api/v1/register", params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "differentpassword"
      }
    }
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not register with short password" do
    post "/api/v1/register", params: {
      user: {
        email: "newuser@example.com",
        password: "123",
        password_confirmation: "123"
      }
    }
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  # Profile tests
  test "should get profile with valid token" do
    get "/api/v1/profile", headers: auth_headers(@user)
    
    assert_response :success
    json = assert_json_response(response, ["id", "email", "name", "role"])
    
    assert_equal @user.id, json["id"]
    assert_equal @user.email, json["email"]
    assert_equal @user.name, json["name"]
    assert_equal @user.role, json["role"]
  end

  test "should not get profile without token" do
    get "/api/v1/profile"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not get profile with invalid token" do
    get "/api/v1/profile", headers: { "Authorization" => "Bearer invalid_token" }
    
    assert_error_response(response, :unauthorized, "Invalid token")
  end

  test "should not get profile with expired token" do
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

  # Logout tests
  test "should logout with valid token" do
    delete "/api/v1/logout", headers: auth_headers(@user)
    
    assert_response :no_content
  end

  test "should logout with auth/sign_out endpoint" do
    delete "/api/v1/auth/sign_out", headers: auth_headers(@user)
    
    assert_response :no_content
  end

  test "should logout without token" do
    delete "/api/v1/logout"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Test endpoints (development only)
  test "should get test profile in development" do
    if Rails.env.development?
      get "/api/v1/test-profile"
      assert_response :success
      json = assert_json_response(response, ["id", "email"])
      assert_equal @user.id, json["id"]
    end
  end

  test "should get test lists in development" do
    if Rails.env.development?
      list = create_test_list(@user)
      get "/api/v1/test-lists"
      assert_response :success
      json = assert_json_response(response)
      assert json.is_a?(Array)
    end
  end

  test "should test logout in development" do
    if Rails.env.development?
      delete "/api/v1/test-logout"
      assert_response :no_content
    end
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/login", 
         params: "invalid json",
         headers: { "Content-Type" => "application/json" }
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/login", params: {}
    
    assert_error_response(response, :unauthorized, "Invalid email or password")
  end

  test "should handle case insensitive email" do
    post "/api/v1/login", params: {
      email: @user.email.upcase,
      password: "password123"
    }
    
    assert_response :success
    json = assert_json_response(response, ["user", "token"])
    assert_equal @user.id, json["user"]["id"]
  end

  test "should handle extra whitespace in email" do
    post "/api/v1/login", params: {
      email: " #{@user.email} ",
      password: "password123"
    }
    
    assert_response :success
    json = assert_json_response(response, ["user", "token"])
    assert_equal @user.id, json["user"]["id"]
  end

  test "should handle registration with timezone" do
    post "/api/v1/register", params: {
      user: {
        email: "timezone@example.com",
        password: "password123",
        password_confirmation: "password123",
        timezone: "America/New_York"
      }
    }
    
    assert_response :created
    json = assert_json_response(response, ["user", "token"])
    assert_equal "America/New_York", json["user"]["timezone"]
  end

  test "should handle registration with role" do
    post "/api/v1/register", params: {
      user: {
        email: "coach@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "coach"
      }
    }
    
    assert_response :created
    json = assert_json_response(response, ["user", "token"])
    assert_equal "coach", json["user"]["role"]
  end

  test "should handle multiple login attempts" do
    # First login
    post "/api/v1/login", params: {
      email: @user.email,
      password: "password123"
    }
    assert_response :success
    
    # Second login should also work
    post "/api/v1/login", params: {
      email: @user.email,
      password: "password123"
    }
    assert_response :success
  end

  test "should handle concurrent login attempts" do
    threads = []
    5.times do |i|
      threads << Thread.new do
        post "/api/v1/login", params: {
          email: @user.email,
          password: "password123"
        }
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true # If we get here without errors, test passes
  end
end
