# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipSerializer do
  let(:owner) { create(:user) }
  let(:member) { create(:user, name: "Carol") }
  let(:list) { create(:list, user: owner) }
  let(:membership) { create(:membership, list: list, user: member, role: "editor") }

  describe "#as_json" do
    it "serializes membership attributes" do
      json = described_class.new(membership).as_json

      expect(json[:id]).to eq(membership.id)
      expect(json[:role]).to eq("editor")
      expect(json[:created_at]).to eq(membership.created_at)
      expect(json[:updated_at]).to eq(membership.updated_at)
    end

    it "nests user data" do
      json = described_class.new(membership).as_json

      expect(json[:user][:id]).to eq(member.id)
      expect(json[:user][:name]).to eq("Carol")
      expect(json[:user]).not_to have_key(:email)
    end
  end
end
