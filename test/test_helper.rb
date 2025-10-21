ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Helper method to create a JWT token for testing
    def create_jwt_token(user)
      JWT.encode(
        {
          user_id: user.id,
          exp: 30.days.from_now.to_i
        },
        Rails.application.credentials.secret_key_base
      )
    end

    # Helper method to authenticate requests
    def auth_headers(user)
      { "Authorization" => "Bearer #{create_jwt_token(user)}" }
    end

  # Helper method to create a test user
  def create_test_user(attributes = {})
    User.create!({
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "client",
      jti: SecureRandom.uuid
    }.merge(attributes))
  end

    # Helper method to create a test list
    def create_test_list(user, attributes = {})
      user.owned_lists.create!({
        name: "Test List",
        description: "A test list"
      }.merge(attributes))
    end

    # Helper method to create a test task
    def create_test_task(list, attributes = {})
      default_attributes = {
        title: "Test Task",
        due_at: 1.hour.from_now,
        creator: list.owner,
        strict_mode: true,
        status: :pending
      }
      list.tasks.create!(default_attributes.merge(attributes))
    end

    # Helper method to assert JSON response structure
    def assert_json_response(response, expected_keys = [])
      assert_response :success
      json = ::JSON.parse(response.body)
      expected_keys.each do |key|
        assert json.key?(key.to_s), "Expected response to include '#{key}' key"
      end
      json
    end

    # Helper method to assert error response
    def assert_error_response(response, status, message = nil)
      assert_response status
      json = ::JSON.parse(response.body)
      assert json.key?("error"), "Expected error response to include 'error' key"
      if message
        assert_equal message, json["error"]["message"]
      end
      json
    end
  end
end
