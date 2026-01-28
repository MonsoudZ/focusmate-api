# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::PasswordChangeService do
  describe ".call!" do
    let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

    context "with valid params" do
      it "changes the password" do
        result = described_class.call!(
          user: user,
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        )

        expect(result).to eq(user)
        expect(user.reload.valid_password?("newpassword456")).to be true
      end

      it "invalidates the old password" do
        described_class.call!(
          user: user,
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        )

        expect(user.reload.valid_password?("password123")).to be false
      end
    end

    context "when user is an Apple Sign In user" do
      let(:apple_user) { create(:user, apple_user_id: "apple_123456") }

      it "raises Forbidden" do
        expect {
          described_class.call!(
            user: apple_user,
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          )
        }.to raise_error(
          Users::PasswordChangeService::Forbidden,
          "Password change not available for Apple Sign In accounts"
        )
      end
    end

    context "when current password is incorrect" do
      it "raises ValidationError" do
        expect {
          described_class.call!(
            user: user,
            current_password: "wrongpassword",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError, "Current password is incorrect")
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(
            user: user,
            current_password: "wrongpassword",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError) do |error|
          expect(error.details).to eq({ current_password: [ "is incorrect" ] })
        end
      end

      it "does not change the password" do
        expect {
          described_class.call!(
            user: user,
            current_password: "wrongpassword",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError)

        expect(user.reload.valid_password?("password123")).to be true
      end
    end

    context "when new password is blank" do
      it "raises ValidationError" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "",
            password_confirmation: ""
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError, "Password is required")
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "",
            password_confirmation: ""
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError) do |error|
          expect(error.details).to eq({ password: [ "can't be blank" ] })
        end
      end
    end

    context "when new password is too short" do
      it "raises ValidationError" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "short",
            password_confirmation: "short"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError, "Password too short")
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "short",
            password_confirmation: "short"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError) do |error|
          expect(error.details).to eq({ password: [ "must be at least 6 characters" ] })
        end
      end
    end

    context "when password confirmation does not match" do
      it "raises ValidationError" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "mismatch789"
          )
        }.to raise_error(
          Users::PasswordChangeService::ValidationError,
          "Password confirmation doesn't match"
        )
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "mismatch789"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError) do |error|
          expect(error.details).to eq({ password_confirmation: [ "doesn't match" ] })
        end
      end

      it "does not change the password" do
        expect {
          described_class.call!(
            user: user,
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "mismatch789"
          )
        }.to raise_error(Users::PasswordChangeService::ValidationError)

        expect(user.reload.valid_password?("password123")).to be true
      end
    end
  end
end
