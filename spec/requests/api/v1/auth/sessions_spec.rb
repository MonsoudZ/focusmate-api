# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Sessions", type: :request do
  describe "POST /api/v1/auth/sign_in" do
    let(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns success with token" do
        post "/api/v1/auth/sign_in",
             params: { user: { email: user.email, password: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json_response["token"]).to be_present
        expect(json_response["user"]).to include("id" => user.id, "email" => user.email)
      end

      it "returns a refresh token" do
        post "/api/v1/auth/sign_in",
             params: { user: { email: user.email, password: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json_response["refresh_token"]).to be_present
      end
    end

    context "with invalid password" do
      it "returns unauthorized" do
        post "/api/v1/auth/sign_in",
             params: { user: { email: user.email, password: "wrongpassword" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with non-existent email" do
      it "returns unauthorized" do
        post "/api/v1/auth/sign_in",
             params: { user: { email: "nobody@example.com", password: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing parameters" do
      it "returns unauthorized for missing email" do
        post "/api/v1/auth/sign_in",
             params: { user: { password: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    let(:user) { create(:user) }

    context "when authenticated" do
      it "signs out successfully" do
        delete "/api/v1/auth/sign_out", headers: auth_headers_for(user)

        expect(response).to have_http_status(:no_content)
      end

      it "invalidates the token" do
        headers = auth_headers_for(user)

        delete "/api/v1/auth/sign_out", headers: headers
        expect(response).to have_http_status(:no_content)

        # Token should now be invalid
        get "/api/v1/users/profile", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "ignores non-scalar refresh_token param" do
        expect(Auth::TokenService).not_to receive(:revoke)

        delete "/api/v1/auth/sign_out",
               params: { refresh_token: { bad: "input" } }.to_json,
               headers: auth_headers_for(user)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when not authenticated" do
      it "returns no content" do
        # Devise typically returns 204 even without auth for sign_out
        delete "/api/v1/auth/sign_out"

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
