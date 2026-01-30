# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Login do
  describe ".call!" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123", password_confirmation: "password123") }

    context "with valid credentials" do
      it "returns the user" do
        result = described_class.call!(email: user.email, password: "password123")

        expect(result).to eq(user)
      end
    end

    context "email normalization" do
      it "strips whitespace from email" do
        result = described_class.call!(email: "  #{user.email}  ", password: "password123")

        expect(result).to eq(user)
      end

      it "downcases email" do
        result = described_class.call!(email: "TEST@EXAMPLE.COM", password: "password123")

        expect(result).to eq(user)
      end

      it "strips and downcases email" do
        result = described_class.call!(email: "  TEST@EXAMPLE.COM  ", password: "password123")

        expect(result).to eq(user)
      end
    end

    context "when email is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(email: "", password: "password123")
        }.to raise_error(ApplicationError::BadRequest, "Email and password are required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(email: nil, password: "password123")
        }.to raise_error(ApplicationError::BadRequest, "Email and password are required")
      end

      it "raises BadRequest with whitespace-only string" do
        expect {
          described_class.call!(email: "   ", password: "password123")
        }.to raise_error(ApplicationError::BadRequest, "Email and password are required")
      end
    end

    context "when password is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(email: "test@example.com", password: "")
        }.to raise_error(ApplicationError::BadRequest, "Email and password are required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(email: "test@example.com", password: nil)
        }.to raise_error(ApplicationError::BadRequest, "Email and password are required")
      end
    end

    context "when password is wrong" do
      it "raises Unauthorized" do
        expect {
          described_class.call!(email: user.email, password: "wrongpassword")
        }.to raise_error(ApplicationError::Unauthorized, "Invalid email or password")
      end
    end

    context "when email does not exist" do
      it "raises Unauthorized with the same message as wrong password" do
        expect {
          described_class.call!(email: "nonexistent@example.com", password: "password123")
        }.to raise_error(ApplicationError::Unauthorized, "Invalid email or password")
      end
    end
  end
end
