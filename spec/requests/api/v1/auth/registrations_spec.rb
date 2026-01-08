# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Registrations", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          timezone: "America/New_York"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new user" do
        expect {
          post "/api/v1/auth/sign_up",
               params: valid_params.to_json,
               headers: { "Content-Type" => "application/json" }
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "returns the user" do
        post "/api/v1/auth/sign_up",
             params: valid_params.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(json_response["user"]).to include(
                                           "email" => "newuser@example.com"
                                         )
      end
    end

    context "with invalid parameters" do
      it "returns error for missing email" do
        post "/api/v1/auth/sign_up",
             params: { user: { password: "password123", password_confirmation: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end

      it "returns error for missing password" do
        post "/api/v1/auth/sign_up",
             params: { user: { email: "test@example.com" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end

      it "returns error for password mismatch" do
        post "/api/v1/auth/sign_up",
             params: { user: { email: "test@example.com", password: "password123", password_confirmation: "different" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end

      it "returns error for duplicate email" do
        create(:user, email: "existing@example.com")

        post "/api/v1/auth/sign_up",
             params: { user: { email: "existing@example.com", password: "password123", password_confirmation: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end

      it "returns error for short password" do
        post "/api/v1/auth/sign_up",
             params: { user: { email: "test@example.com", password: "short", password_confirmation: "short" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end

      it "returns error for invalid email format" do
        post "/api/v1/auth/sign_up",
             params: { user: { email: "notanemail", password: "password123", password_confirmation: "password123" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response.status).to be_in([ 400, 422 ])
      end
    end
  end
end
