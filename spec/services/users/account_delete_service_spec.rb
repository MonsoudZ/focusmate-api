# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::AccountDeleteService do
  describe ".call!" do
    context "when user is an email user with correct password" do
      let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

      it "deletes the user" do
        described_class.call!(user: user, password: "password123")

        expect(User.find_by(id: user.id)).to be_nil
      end

      it "returns the destroyed user" do
        result = described_class.call!(user: user, password: "password123")

        expect(result).to eq(user)
        expect(result).to be_destroyed
      end
    end

    context "when user is an Apple Sign In user" do
      let(:apple_user) { create(:user, apple_user_id: "apple_123456") }

      it "deletes the user without requiring a password" do
        described_class.call!(user: apple_user)

        expect(User.find_by(id: apple_user.id)).to be_nil
      end

      it "deletes the user even when password is nil" do
        described_class.call!(user: apple_user, password: nil)

        expect(User.find_by(id: apple_user.id)).to be_nil
      end
    end

    context "when password is wrong for an email user" do
      let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

      it "raises ValidationError" do
        expect {
          described_class.call!(user: user, password: "wrongpassword")
        }.to raise_error(ApplicationError::Validation, "Password is incorrect")
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(user: user, password: "wrongpassword")
        }.to raise_error(ApplicationError::Validation) do |error|
          expect(error.details).to eq({ password: [ "is incorrect" ] })
        end
      end

      it "does not delete the user" do
        expect {
          described_class.call!(user: user, password: "wrongpassword")
        }.to raise_error(ApplicationError::Validation)

        expect(User.find_by(id: user.id)).to eq(user)
      end
    end

    context "when password is nil for an email user" do
      let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

      it "raises ValidationError" do
        expect {
          described_class.call!(user: user, password: nil)
        }.to raise_error(ApplicationError::Validation, "Password is incorrect")
      end

      it "includes field-specific error details" do
        expect {
          described_class.call!(user: user, password: nil)
        }.to raise_error(ApplicationError::Validation) do |error|
          expect(error.details).to eq({ password: [ "is incorrect" ] })
        end
      end

      it "does not delete the user" do
        expect {
          described_class.call!(user: user, password: nil)
        }.to raise_error(ApplicationError::Validation)

        expect(User.find_by(id: user.id)).to eq(user)
      end
    end
  end
end
