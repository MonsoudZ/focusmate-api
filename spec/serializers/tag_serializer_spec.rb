# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagSerializer do
  let(:user) { create(:user) }
  let(:tag) { create(:tag, user: user, name: "Urgent", color: "red") }

  describe "#as_json" do
    it "serializes tag attributes" do
      json = described_class.new(tag).as_json

      expect(json[:id]).to eq(tag.id)
      expect(json[:name]).to eq("Urgent")
      expect(json[:color]).to eq("red")
      expect(json[:tasks_count]).to eq(0)
      expect(json[:created_at]).to eq(tag.created_at)
    end

    it "returns exactly five keys" do
      json = described_class.new(tag).as_json

      expect(json.keys).to match_array(%i[id name color tasks_count created_at])
    end
  end
end
