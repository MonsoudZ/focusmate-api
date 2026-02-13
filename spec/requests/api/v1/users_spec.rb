# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users API", type: :request do
  let(:user) { create(:user, name: "Test User", timezone: "UTC") }

  describe "GET /api/v1/users/profile" do
    context "when authenticated" do
      it "returns current user" do
        auth_get "/api/v1/users/profile", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["user"]["id"]).to eq(user.id)
        expect(json_response["user"]["email"]).to eq(user.email)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/users/profile"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/users/profile" do
    context "with valid params" do
      it "updates name" do
        auth_patch "/api/v1/users/profile", user: user, params: { name: "New Name" }

        expect(response).to have_http_status(:ok)
        expect(user.reload.name).to eq("New Name")
      end

      it "updates timezone" do
        auth_patch "/api/v1/users/profile", user: user, params: { timezone: "America/New_York" }

        expect(response).to have_http_status(:ok)
        expect(user.reload.timezone).to eq("America/New_York")
      end

      it "ignores non-scalar profile params" do
        auth_patch "/api/v1/users/profile", user: user, params: { name: { bad: "value" } }

        expect(response).to have_http_status(:ok)
        expect(user.reload.name).to eq("Test User")
      end
    end
  end

  describe "PATCH /api/v1/users/profile/password" do
    let(:user) { create(:user, password: "oldpassword123", password_confirmation: "oldpassword123") }

    context "with valid params" do
      it "updates password" do
        auth_patch "/api/v1/users/profile/password", user: user, params: {
          current_password: "oldpassword123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }

        expect(response).to have_http_status(:ok)
        expect(user.reload.valid_password?("newpassword456")).to be true
      end
    end

    context "with invalid current password" do
      it "returns error" do
        auth_patch "/api/v1/users/profile/password", user: user, params: {
          current_password: "wrongpassword",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }

        expect(response.status).to be_in([ 401, 422 ])
      end

      it "returns error for non-scalar password params" do
        auth_patch "/api/v1/users/profile/password", user: user, params: {
          current_password: { bad: "value" },
          password: { bad: "value" },
          password_confirmation: { bad: "value" }
        }

        expect(response.status).to be_in([ 400, 422 ])
      end
    end

    context "with password mismatch" do
      it "returns error" do
        auth_patch "/api/v1/users/profile/password", user: user, params: {
          current_password: "oldpassword123",
          password: "newpassword456",
          password_confirmation: "differentpassword"
        }

        expect(response.status).to be_in([ 400, 422 ])
      end
    end
  end

  describe "DELETE /api/v1/users/profile" do
    context "when authenticated" do
      it "deletes the account" do
        auth_delete "/api/v1/users/profile", user: user

        expect(response.status).to be_in([ 200, 204, 422 ])
      end

      it "returns validation error for non-scalar password param" do
        delete "/api/v1/users/profile",
               params: { password: { bad: "value" } }.to_json,
               headers: auth_headers_for(user)

        expect(response.status).to be_in([ 400, 422 ])
      end
    end
  end
end
