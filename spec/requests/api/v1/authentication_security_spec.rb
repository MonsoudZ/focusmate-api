# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Authentication Security", type: :request do
  let(:user_a) { create(:user, email: "user_a@example.com") }
  let(:user_b) { create(:user, email: "user_b@example.com") }
  let(:list_a) { create(:list, user: user_a) }
  let!(:task_a) { create(:task, list: list_a, creator: user_a, title: "User A's Task") }

  def auth_headers(user)
    token = JwtHelper.access_for(user)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "Unauthenticated access" do
    it "returns 401 for protected endpoints without token" do
      get "/api/v1/tasks/all_tasks"
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/lists"
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/profile"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with proper error message" do
      get "/api/v1/tasks/all_tasks"
      json = JSON.parse(response.body)
      expect(json).to have_key("error")
      expect(json["error"]).to have_key("message")
    end
  end

  describe "Cross-user access protection" do
    it "prevents user B from accessing user A's task" do
      get "/api/v1/lists/#{list_a.id}/tasks/#{task_a.id}", headers: auth_headers(user_b)

      # Should return 403 Forbidden or 404 Not Found (both are acceptable)
      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end

    it "allows user A to access their own task" do
      get "/api/v1/lists/#{list_a.id}/tasks/#{task_a.id}", headers: auth_headers(user_a)
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json).to have_key("id")
      expect(json["id"]).to eq(task_a.id)
    end

    it "prevents user B from accessing user A's list" do
      get "/api/v1/lists/#{list_a.id}/tasks", headers: auth_headers(user_b)
      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end

    it "allows user A to access their own list" do
      get "/api/v1/lists/#{list_a.id}/tasks", headers: auth_headers(user_a)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Invalid token handling" do
    it "rejects invalid token format" do
      get "/api/v1/profile", headers: { "Authorization" => "InvalidToken" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects expired token" do
      expired_payload = {
        user_id: user_a.id,
        exp: 1.hour.ago.to_i,
        iat: 2.hours.ago.to_i
      }
      expired_token = JWT.encode(expired_payload, Rails.application.secret_key_base, "HS256")

      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{expired_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects token with wrong secret" do
      wrong_token = JWT.encode(
        { user_id: user_a.id, exp: 1.hour.from_now.to_i },
        "wrong_secret",
        "HS256"
      )

      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{wrong_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

