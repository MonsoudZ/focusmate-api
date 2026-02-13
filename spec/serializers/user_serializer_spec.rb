# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { create(:user, name: "Alice", timezone: "America/New_York") }

  describe ".one" do
    it "serializes basic user attributes" do
      json = described_class.one(user)

      expect(json[:id]).to eq(user.id)
      expect(json[:email]).to eq(user.email)
      expect(json[:name]).to eq("Alice")
      expect(json[:role]).to eq("client")
      expect(json[:timezone]).to eq("America/New_York")
    end

    it "sets has_password true when apple_user_id is blank" do
      json = described_class.one(user)

      expect(json[:has_password]).to be true
    end

    it "sets has_password false when apple_user_id is present" do
      user.update_column(:apple_user_id, "001234.abc")
      json = described_class.one(user)

      expect(json[:has_password]).to be false
    end
  end
end
