# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  let(:user) { create(:user) }

  def auth_headers_for(u)
    post "/api/v1/auth/sign_in",
         params: { user: { email: u.email, password: "password123" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  describe "IP-based throttles" do
    it "allows requests under the general API limit" do
      headers = auth_headers_for(user)

      get "/api/v1/tasks", headers: headers
      expect(response.status).not_to eq(429)
    end

    it "throttles authentication endpoints after 5 requests" do
      6.times do
        post "/api/v1/auth/sign_in",
             params: { user: { email: "test@test.com", password: "wrong" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to include("Rate limit exceeded")
    end

    it "throttles Apple auth endpoint" do
      6.times do
        post "/api/v1/auth/apple",
             params: { id_token: "fake" }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
    end

    it "throttles token refresh endpoint after 10 requests" do
      11.times do
        post "/api/v1/auth/refresh",
             params: { refresh_token: "fake" }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
    end

    it "throttles password reset request endpoint after 3 requests" do
      4.times do
        post "/api/v1/auth/password",
             params: { user: { email: "test@test.com" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
    end

    it "throttles password reset token submit endpoint after 3 requests" do
      4.times do
        put "/api/v1/auth/password",
            params: {
              user: {
                reset_password_token: "fake",
                password: "new-password-123",
                password_confirmation: "new-password-123"
              }
            }.to_json,
            headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
    end
  end

  describe "throttled response format" do
    it "includes Retry-After header" do
      6.times do
        post "/api/v1/auth/sign_in",
             params: { user: { email: "test@test.com", password: "wrong" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "returns JSON error body with retry_after and timestamp" do
      6.times do
        post "/api/v1/auth/sign_in",
             params: { user: { email: "test@test.com", password: "wrong" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(response.status).to eq(429)
      json = JSON.parse(response.body)
      expect(json["error"]).to have_key("message")
      expect(json["error"]).to have_key("retry_after")
      expect(json["error"]).to have_key("timestamp")
    end
  end

  describe "user ID extraction" do
    it "extracts user ID from valid JWT" do
      headers = auth_headers_for(user)
      token = headers["Authorization"].remove("Bearer ")

      req = Rack::Attack::Request.new(
        Rack::MockRequest.env_for("/api/v1/tasks", "HTTP_AUTHORIZATION" => "Bearer #{token}")
      )

      user_id = Rack::Attack.authenticated_user_id(req)
      expect(user_id).to eq(user.id.to_s)
    end

    it "returns nil for missing token" do
      req = Rack::Attack::Request.new(
        Rack::MockRequest.env_for("/api/v1/tasks")
      )

      user_id = Rack::Attack.authenticated_user_id(req)
      expect(user_id).to be_nil
    end

    it "returns nil for invalid token" do
      req = Rack::Attack::Request.new(
        Rack::MockRequest.env_for("/api/v1/tasks", "HTTP_AUTHORIZATION" => "Bearer invalid.token.here")
      )

      user_id = Rack::Attack.authenticated_user_id(req)
      expect(user_id).to be_nil
    end
  end
end
