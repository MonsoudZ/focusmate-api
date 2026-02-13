# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Passwords", type: :request do
  describe "POST /api/v1/auth/password" do
    let(:user) { create(:user, email: "test@example.com") }

    it "returns success message for existing email" do
      post "/api/v1/auth/password",
           params: { user: { email: user.email } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to match(/reset instructions/i)
    end

    it "sends a reset email with frontend URL for existing email" do
      post "/api/v1/auth/password",
           params: { user: { email: user.email } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to eq([ user.email ])
      expect(email.text_part.body.to_s).to include("/reset-password?token=")
      expect(email.html_part.body.to_s).to include("/reset-password?token=")
    end

    it "returns same success message for non-existent email" do
      post "/api/v1/auth/password",
           params: { user: { email: "nonexistent@example.com" } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to match(/reset instructions/i)
    end

    it "does not send an email for non-existent email" do
      post "/api/v1/auth/password",
           params: { user: { email: "nonexistent@example.com" } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "always returns 200 regardless of email existence" do
      # Security: response is identical for existing and non-existing emails
      post "/api/v1/auth/password",
           params: { user: { email: user.email } }.to_json,
           headers: { "Content-Type" => "application/json" }
      existing_body = json_response

      ActionMailer::Base.deliveries.clear

      post "/api/v1/auth/password",
           params: { user: { email: "fake@nowhere.com" } }.to_json,
           headers: { "Content-Type" => "application/json" }
      fake_body = json_response

      expect(existing_body).to eq(fake_body)
    end
  end

  describe "PUT /api/v1/auth/password" do
    let(:user) { create(:user, email: "test@example.com") }

    it "resets password with valid token" do
      raw_token = user.send(:set_reset_password_token)
      user.save!

      put "/api/v1/auth/password",
          params: {
            user: {
              reset_password_token: raw_token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to match(/updated successfully/i)
    end

    it "returns validation error with invalid token" do
      put "/api/v1/auth/password",
          params: {
            user: {
              reset_password_token: "invalid-token",
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["code"]).to eq("validation_error")
      expect(json_response["error"]["details"]).to have_key("reset_password_token")
    end

    it "returns validation error when passwords do not match" do
      raw_token = user.send(:set_reset_password_token)
      user.save!

      put "/api/v1/auth/password",
          params: {
            user: {
              reset_password_token: raw_token,
              password: "newpassword123",
              password_confirmation: "differentpassword"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["details"]).to have_key("password_confirmation")
    end

    it "returns validation error when password is too short" do
      raw_token = user.send(:set_reset_password_token)
      user.save!

      put "/api/v1/auth/password",
          params: {
            user: {
              reset_password_token: raw_token,
              password: "short",
              password_confirmation: "short"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["details"]).to have_key("password")
    end
  end
end
