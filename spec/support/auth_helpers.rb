# frozen_string_literal: true

# spec/support/auth_helpers.rb
#
# Shared authentication helpers for request specs.
# Include in spec/rails_helper.rb:
#   Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
#
module AuthHelpers
  # Get authentication headers for a user
  #
  # @param user [User] The user to authenticate as
  # @return [Hash] Headers including Authorization token
  #
  def auth_headers_for(user)
    # Generate JWT token directly using Warden
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first

    {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  # Make an authenticated GET request
  def auth_get(path, user:, params: {})
    get path, params: params, headers: auth_headers_for(user)
  end

  # Make an authenticated POST request
  def auth_post(path, user:, params: {})
    post path, params: params.to_json, headers: auth_headers_for(user)
  end

  # Make an authenticated PATCH request
  def auth_patch(path, user:, params: {})
    patch path, params: params.to_json, headers: auth_headers_for(user)
  end

  # Make an authenticated PUT request
  def auth_put(path, user:, params: {})
    put path, params: params.to_json, headers: auth_headers_for(user)
  end

  # Make an authenticated DELETE request
  def auth_delete(path, user:)
    delete path, headers: auth_headers_for(user)
  end

  # Parse JSON response body
  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end