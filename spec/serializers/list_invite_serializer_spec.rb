# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListInviteSerializer do
  let(:owner) { create(:user, name: "Owner") }
  let(:list) { create(:list, user: owner, name: "Shopping", color: "green") }
  let(:invite) { create(:list_invite, list: list, inviter: owner, role: "viewer") }

  describe "#as_json" do
    it "serializes invite attributes" do
      json = described_class.new(invite).as_json

      expect(json[:id]).to eq(invite.id)
      expect(json[:code]).to eq(invite.code)
      expect(json[:role]).to eq("viewer")
      expect(json[:invite_url]).to eq(invite.invite_url)
      expect(json[:expires_at]).to eq(invite.expires_at)
      expect(json[:max_uses]).to be_nil
      expect(json[:uses_count]).to eq(0)
      expect(json[:usable]).to be true
      expect(json[:created_at]).to eq(invite.created_at)
    end
  end

  describe "#as_preview_json" do
    it "returns limited info for unauthenticated users" do
      json = described_class.new(invite).as_preview_json

      expect(json[:code]).to eq(invite.code)
      expect(json[:role]).to eq("viewer")
      expect(json[:usable]).to be true
      expect(json[:expired]).to be false
      expect(json[:exhausted]).to be false
    end

    it "nests list data" do
      json = described_class.new(invite).as_preview_json

      expect(json[:list][:id]).to eq(list.id)
      expect(json[:list][:name]).to eq("Shopping")
      expect(json[:list][:color]).to eq("green")
    end

    it "nests inviter name only" do
      json = described_class.new(invite).as_preview_json

      expect(json[:inviter][:name]).to eq("Owner")
      expect(json[:inviter]).not_to have_key(:email)
    end

    it "does not expose id or invite_url" do
      json = described_class.new(invite).as_preview_json

      expect(json).not_to have_key(:id)
      expect(json).not_to have_key(:invite_url)
    end

    it "reflects expired status" do
      invite = create(:list_invite, :expired, list: list, inviter: owner)
      json = described_class.new(invite).as_preview_json

      expect(json[:expired]).to be true
    end

    it "reflects exhausted status" do
      invite = create(:list_invite, :exhausted, list: list, inviter: owner)
      json = described_class.new(invite).as_preview_json

      expect(json[:exhausted]).to be true
    end
  end
end
