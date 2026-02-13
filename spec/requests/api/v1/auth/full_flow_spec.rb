# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Full Flow E2E", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  describe "complete authentication lifecycle" do
    let(:email) { "newuser@example.com" }
    let(:password) { "securepassword123" }

    it "signup → login → access protected resource → refresh → logout → verify token invalid" do
      # ==========================================
      # Step 1: Sign up a new user
      # ==========================================
      post "/api/v1/auth/sign_up",
           params: { user: { email: email, password: password, password_confirmation: password, name: "Test User", timezone: "America/New_York" } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:created)
      signup_response = json_response
      expect(signup_response["user"]["email"]).to eq(email)
      expect(signup_response["token"]).to be_present
      expect(signup_response["refresh_token"]).to be_present

      signup_access_token = signup_response["token"]
      signup_refresh_token = signup_response["refresh_token"]
      user_id = signup_response["user"]["id"]

      # ==========================================
      # Step 2: Access protected resource with signup token
      # ==========================================
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{signup_access_token}")

      expect(response).to have_http_status(:ok)
      expect(json_response["user"]["id"]).to eq(user_id)

      # ==========================================
      # Step 3: Sign out to invalidate signup tokens
      # ==========================================
      delete "/api/v1/auth/sign_out",
             headers: json_headers.merge("Authorization" => "Bearer #{signup_access_token}")

      expect(response).to have_http_status(:no_content)

      # ==========================================
      # Step 4: Verify signup token is now invalid
      # ==========================================
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{signup_access_token}")

      expect(response).to have_http_status(:unauthorized)

      # ==========================================
      # Step 5: Log in with credentials
      # ==========================================
      post "/api/v1/auth/sign_in",
           params: { user: { email: email, password: password } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      login_response = json_response
      expect(login_response["token"]).to be_present
      expect(login_response["refresh_token"]).to be_present

      login_access_token = login_response["token"]
      login_refresh_token = login_response["refresh_token"]

      # Tokens should be different from signup tokens
      expect(login_access_token).not_to eq(signup_access_token)
      expect(login_refresh_token).not_to eq(signup_refresh_token)

      # ==========================================
      # Step 6: Access protected resource with login token
      # ==========================================
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{login_access_token}")

      expect(response).to have_http_status(:ok)
      expect(json_response["user"]["email"]).to eq(email)

      # ==========================================
      # Step 7: Refresh the token
      # ==========================================
      post "/api/v1/auth/refresh",
           params: { refresh_token: login_refresh_token }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      refresh_response = json_response
      expect(refresh_response["token"]).to be_present
      expect(refresh_response["refresh_token"]).to be_present

      refreshed_access_token = refresh_response["token"]
      refreshed_refresh_token = refresh_response["refresh_token"]

      # Refreshed tokens should be different
      expect(refreshed_access_token).not_to eq(login_access_token)
      expect(refreshed_refresh_token).not_to eq(login_refresh_token)

      # ==========================================
      # Step 8: Access protected resource with refreshed token
      # ==========================================
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{refreshed_access_token}")

      expect(response).to have_http_status(:ok)

      # ==========================================
      # Step 9: Old refresh token should be invalid (token rotation)
      # ==========================================
      post "/api/v1/auth/refresh",
           params: { refresh_token: login_refresh_token }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unauthorized)

      # ==========================================
      # Step 10: Sign out with refreshed token
      # ==========================================
      delete "/api/v1/auth/sign_out",
             headers: json_headers.merge("Authorization" => "Bearer #{refreshed_access_token}")

      expect(response).to have_http_status(:no_content)

      # ==========================================
      # Step 11: Verify the logged-out token is invalid
      # ==========================================
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{refreshed_access_token}")

      expect(response).to have_http_status(:unauthorized)

      # Note: Other tokens remain valid (JWT-based auth only revokes the specific token used for logout)
      # This is expected behavior - each session/device can logout independently
    end
  end

  describe "token reuse attack detection" do
    let(:user) { create(:user) }

    it "revokes entire token family when refresh token is reused after grace period" do
      # Login to get initial tokens
      post "/api/v1/auth/sign_in",
           params: { user: { email: user.email, password: "password123" } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      original_refresh_token = json_response["refresh_token"]

      # First refresh (legitimate)
      post "/api/v1/auth/refresh",
           params: { refresh_token: original_refresh_token }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      second_refresh_token = json_response["refresh_token"]

      # Second refresh with new token (legitimate)
      post "/api/v1/auth/refresh",
           params: { refresh_token: second_refresh_token }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      third_refresh_token = json_response["refresh_token"]

      # Attacker tries to use the stolen original refresh token (after grace period)
      travel 15.seconds do
        post "/api/v1/auth/refresh",
             params: { refresh_token: original_refresh_token }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unauthorized)

        # The entire family should be revoked - third token should now be invalid
        post "/api/v1/auth/refresh",
             params: { refresh_token: third_refresh_token }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "concurrent session management" do
    let(:user) { create(:user) }

    it "allows multiple active sessions" do
      # Login from "device 1"
      post "/api/v1/auth/sign_in",
           params: { user: { email: user.email, password: "password123" } }.to_json,
           headers: json_headers

      device1_token = json_response["token"]

      # Login from "device 2"
      post "/api/v1/auth/sign_in",
           params: { user: { email: user.email, password: "password123" } }.to_json,
           headers: json_headers

      device2_token = json_response["token"]

      # Both sessions should work
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{device1_token}")
      expect(response).to have_http_status(:ok)

      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{device2_token}")
      expect(response).to have_http_status(:ok)

      # Logout device 1
      delete "/api/v1/auth/sign_out",
             headers: json_headers.merge("Authorization" => "Bearer #{device1_token}")

      # Device 1 token should be invalid
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{device1_token}")
      expect(response).to have_http_status(:unauthorized)

      # Device 2 should still work
      get "/api/v1/users/profile",
          headers: json_headers.merge("Authorization" => "Bearer #{device2_token}")
      expect(response).to have_http_status(:ok)
    end
  end
end
