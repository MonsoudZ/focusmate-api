# frozen_string_literal: true

require "rails_helper"

RSpec.describe Colorable, type: :model do
  # Use Tag as the test subject since it includes Colorable
  let(:user) { create(:user) }

  describe "COLORS" do
    it "defines the allowed color palette" do
      expect(Colorable::COLORS).to eq(%w[blue green orange red purple pink teal yellow gray])
    end
  end

  describe "color validation" do
    it "accepts valid colors" do
      Colorable::COLORS.each do |color|
        tag = build(:tag, user: user, color: color)
        expect(tag).to be_valid, "Expected color '#{color}' to be valid"
      end
    end

    it "rejects invalid colors" do
      tag = build(:tag, user: user, color: "neon")
      expect(tag).not_to be_valid
      expect(tag.errors[:color]).to be_present
    end

    it "allows nil color" do
      tag = build(:tag, user: user, color: nil)
      expect(tag).to be_valid
    end
  end
end
