# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Apple", type: :request do
  describe "POST /api/v1/auth/apple" do
    it "returns bad request when id_token is missing" do
      post "/api/v1/auth/apple",
           params: {}.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json_response.dig("error", "message")).to eq("id_token is required")
    end

    it "returns bad request when id_token is non-scalar" do
      post "/api/v1/auth/apple",
           params: { id_token: { bad: "input" } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json_response.dig("error", "message")).to eq("id_token is required")
    end

    it "ignores non-scalar name params" do
      user = create(:user, email: "apple-user@example.com", apple_user_id: "apple-sub-123")
      claims = { "sub" => "apple-sub-123", "email" => "apple-user@example.com" }

      allow(Auth::AppleTokenDecoder).to receive(:decode).and_return(claims)
      expect(UserFinder).to receive(:find_or_create_by_apple).with(
        apple_user_id: "apple-sub-123",
        email: "apple-user@example.com",
        name: nil
      ).and_return(user)
      allow(Auth::TokenService).to receive(:issue_pair).and_return(
        access_token: "test-access",
        refresh_token: "test-refresh"
      )

      post "/api/v1/auth/apple",
           params: { id_token: "token", name: { bad: "input" } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json_response["token"]).to eq("test-access")
      expect(json_response["refresh_token"]).to eq("test-refresh")
    end
  end
end
