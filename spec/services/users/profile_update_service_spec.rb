# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::ProfileUpdateService do
  describe ".call!" do
    let(:user) { create(:user, name: "Original Name", timezone: "America/New_York") }

    context "when updating name only" do
      it "updates the user name" do
        result = described_class.call!(user: user, name: "New Name")

        expect(result).to eq(user)
        expect(user.reload.name).to eq("New Name")
      end

      it "does not change the timezone" do
        described_class.call!(user: user, name: "New Name")

        expect(user.reload.timezone).to eq("America/New_York")
      end
    end

    context "when updating timezone only" do
      it "updates the user timezone" do
        result = described_class.call!(user: user, timezone: "Europe/London")

        expect(result).to eq(user)
        expect(user.reload.timezone).to eq("Europe/London")
      end

      it "does not change the name" do
        described_class.call!(user: user, timezone: "Europe/London")

        expect(user.reload.name).to eq("Original Name")
      end
    end

    context "when updating both name and timezone" do
      it "updates both attributes" do
        result = described_class.call!(user: user, name: "Updated Name", timezone: "US/Pacific")

        expect(result).to eq(user)
        user.reload
        expect(user.name).to eq("Updated Name")
        expect(user.timezone).to eq("US/Pacific")
      end
    end

    context "when no attributes are given" do
      it "returns the user unchanged" do
        result = described_class.call!(user: user)

        expect(result).to eq(user)
        user.reload
        expect(user.name).to eq("Original Name")
        expect(user.timezone).to eq("America/New_York")
      end

      it "does not trigger an update query" do
        expect(user).not_to receive(:update!)

        described_class.call!(user: user)
      end
    end

    context "when timezone is invalid" do
      it "raises a ValidationError" do
        expect {
          described_class.call!(user: user, timezone: "Invalid/Timezone")
        }.to raise_error(ApplicationError::Validation, "Invalid timezone")
      end

      it "includes details with the timezone error" do
        expect {
          described_class.call!(user: user, timezone: "Not_A_Zone")
        }.to raise_error(ApplicationError::Validation) do |error|
          expect(error.details).to eq({ timezone: [ "is not a valid timezone" ] })
        end
      end

      it "does not update the user" do
        expect {
          described_class.call!(user: user, timezone: "Invalid/Timezone")
        }.to raise_error(ApplicationError::Validation)

        expect(user.reload.timezone).to eq("America/New_York")
      end
    end

    context "when extra attributes are passed" do
      it "ignores attributes other than name and timezone" do
        result = described_class.call!(user: user, name: "New Name", email: "hacker@evil.com")

        expect(result).to eq(user)
        user.reload
        expect(user.name).to eq("New Name")
        expect(user.email).not_to eq("hacker@evil.com")
      end

      it "returns user unchanged when only extra attributes are given" do
        original_email = user.email

        result = described_class.call!(user: user, email: "hacker@evil.com", role: "admin")

        expect(result).to eq(user)
        expect(user.reload.email).to eq(original_email)
      end
    end
  end
end
