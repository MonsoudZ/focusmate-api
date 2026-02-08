# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFinder do
  describe ".find_by_identifier" do
    let!(:user) { create(:user, email: "test@example.com") }

    context "with email" do
      it "finds user by email" do
        result = described_class.find_by_identifier("test@example.com")
        expect(result).to eq(user)
      end

      it "finds user by email case-insensitively" do
        result = described_class.find_by_identifier("TEST@EXAMPLE.COM")
        expect(result).to eq(user)
      end

      it "returns nil for unknown email" do
        result = described_class.find_by_identifier("unknown@example.com")
        expect(result).to be_nil
      end
    end

    context "with numeric ID" do
      it "finds user by ID" do
        result = described_class.find_by_identifier(user.id.to_s)
        expect(result).to eq(user)
      end

      it "returns nil for unknown ID" do
        result = described_class.find_by_identifier("999999")
        expect(result).to be_nil
      end
    end

    context "with blank identifier" do
      it "returns nil for nil" do
        expect(described_class.find_by_identifier(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.find_by_identifier("")).to be_nil
      end

      it "returns nil for whitespace" do
        expect(described_class.find_by_identifier("   ")).to be_nil
      end
    end
  end

  describe ".find_by_identifier!" do
    let!(:user) { create(:user, email: "test@example.com") }

    it "returns user when found" do
      result = described_class.find_by_identifier!("test@example.com")
      expect(result).to eq(user)
    end

    it "raises error when not found" do
      expect {
        described_class.find_by_identifier!("unknown@example.com")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".find_or_create_by_apple" do
    let(:apple_user_id) { "001234.abc123def456.7890" }
    let(:email) { "user@example.com" }
    let(:name) { "John Doe" }

    context "when user exists by apple_user_id" do
      let!(:existing_user) { create(:user, apple_user_id: apple_user_id) }

      it "returns the existing user" do
        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: email,
          name: name
        )
        expect(result).to eq(existing_user)
      end

      it "does not create a new user" do
        expect {
          described_class.find_or_create_by_apple(
            apple_user_id: apple_user_id,
            email: email,
            name: name
          )
        }.not_to change(User, :count)
      end
    end

    context "when user exists by email" do
      let!(:existing_user) { create(:user, email: email, apple_user_id: nil) }

      it "links apple_user_id to existing user" do
        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: email,
          name: name
        )
        expect(result).to eq(existing_user)
        expect(result.apple_user_id).to eq(apple_user_id)
      end
    end

    context "when user does not exist" do
      it "creates a new user" do
        expect {
          described_class.find_or_create_by_apple(
            apple_user_id: apple_user_id,
            email: email,
            name: name
          )
        }.to change(User, :count).by(1)
      end

      it "sets the correct attributes" do
        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: email,
          name: name
        )
        expect(result.email).to eq(email)
        expect(result.apple_user_id).to eq(apple_user_id)
        expect(result.name).to eq(name)
      end
    end

    context "when email is nil" do
      it "creates user with private relay email" do
        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: nil,
          name: name
        )
        expect(result.email).to eq("#{apple_user_id}@privaterelay.appleid.com")
      end
    end

    context "when a concurrent request wins the race (RecordNotUnique)" do
      it "retries the find by apple_user_id after uniqueness violation" do
        call_count = 0
        allow(User).to receive(:create!).and_wrap_original do |method, **args|
          call_count += 1
          if call_count == 1
            # Simulate concurrent insert that won the race
            create(:user, email: email, apple_user_id: apple_user_id, name: name)
            raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint"
          end
          method.call(**args)
        end

        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: email,
          name: name
        )
        expect(result).to be_persisted
        expect(result.apple_user_id).to eq(apple_user_id)
      end

      it "retries the find by email after uniqueness violation" do
        call_count = 0
        allow(User).to receive(:create!).and_wrap_original do |method, **args|
          call_count += 1
          if call_count == 1
            # Concurrent request created user with same email but different apple_user_id
            create(:user, email: email, apple_user_id: "other_apple_id")
            raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint"
          end
          method.call(**args)
        end

        result = described_class.find_or_create_by_apple(
          apple_user_id: apple_user_id,
          email: email,
          name: name
        )
        expect(result).to be_persisted
        expect(result.email).to eq(email)
      end
    end
  end
end
