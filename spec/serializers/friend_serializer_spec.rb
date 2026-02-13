# frozen_string_literal: true

require "rails_helper"

RSpec.describe FriendSerializer do
  let(:user) { create(:user, name: "Bob") }

  describe "#as_json" do
    it "serializes friend attributes" do
      json = described_class.new(user).as_json

      expect(json[:id]).to eq(user.id)
      expect(json[:name]).to eq("Bob")
      expect(json).not_to have_key(:email)
    end

    it "returns exactly two keys" do
      json = described_class.new(user).as_json

      expect(json.keys).to match_array(%i[id name])
    end
  end
end
