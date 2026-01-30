# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Register do
  describe ".call!" do
    let(:valid_params) do
      {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "John Doe",
        timezone: "America/New_York"
      }
    end

    context "with valid params" do
      it "creates a new user" do
        expect {
          described_class.call!(**valid_params)
        }.to change(User, :count).by(1)
      end

      it "returns the created user" do
        result = described_class.call!(**valid_params)

        expect(result).to be_a(User)
        expect(result).to be_persisted
        expect(result.email).to eq("newuser@example.com")
        expect(result.name).to eq("John Doe")
        expect(result.timezone).to eq("America/New_York")
      end
    end

    context "email normalization" do
      it "strips whitespace from email" do
        result = described_class.call!(**valid_params.merge(email: "  newuser@example.com  "))

        expect(result.email).to eq("newuser@example.com")
      end

      it "downcases email" do
        result = described_class.call!(**valid_params.merge(email: "NEWUSER@EXAMPLE.COM"))

        expect(result.email).to eq("newuser@example.com")
      end

      it "strips and downcases email" do
        result = described_class.call!(**valid_params.merge(email: "  NEWUSER@EXAMPLE.COM  "))

        expect(result.email).to eq("newuser@example.com")
      end
    end

    context "when email is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(**valid_params.merge(email: ""))
        }.to raise_error(ApplicationError::BadRequest, "Email is required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(**valid_params.merge(email: nil))
        }.to raise_error(ApplicationError::BadRequest, "Email is required")
      end

      it "raises BadRequest with whitespace-only string" do
        expect {
          described_class.call!(**valid_params.merge(email: "   "))
        }.to raise_error(ApplicationError::BadRequest, "Email is required")
      end
    end

    context "when password is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(**valid_params.merge(password: ""))
        }.to raise_error(ApplicationError::BadRequest, "Password is required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(**valid_params.merge(password: nil))
        }.to raise_error(ApplicationError::BadRequest, "Password is required")
      end
    end

    context "when email is already taken" do
      before { create(:user, email: "newuser@example.com") }

      it "raises ActiveRecord::RecordInvalid" do
        expect {
          described_class.call!(**valid_params)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when name is not provided" do
      it "sets a default name" do
        result = described_class.call!(**valid_params.merge(name: nil))

        expect(result.name).to eq("User")
      end
    end

    context "when role is not explicitly set" do
      it "defaults to client" do
        result = described_class.call!(**valid_params)

        expect(result.role).to eq("client")
      end
    end
  end
end
