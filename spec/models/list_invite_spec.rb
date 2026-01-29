# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListInvite, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:list) }
    it { is_expected.to belong_to(:inviter).class_name("User") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[viewer editor]) }

    it "validates uniqueness of code" do
      existing = create(:list_invite)
      duplicate = build(:list_invite, code: existing.code)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to include("has already been taken")
    end
  end

  describe "code generation" do
    it "auto-generates a unique code on create" do
      invite = create(:list_invite)
      expect(invite.code).to be_present
      expect(invite.code.length).to eq(8)
    end

    it "generates uppercase alphanumeric codes" do
      invite = create(:list_invite)
      expect(invite.code).to match(/\A[A-Z0-9]+\z/)
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      invite = build(:list_invite, expires_at: nil)
      expect(invite.expired?).to be false
    end

    it "returns false when expires_at is in the future" do
      invite = build(:list_invite, expires_at: 1.day.from_now)
      expect(invite.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      invite = build(:list_invite, expires_at: 1.day.ago)
      expect(invite.expired?).to be true
    end
  end

  describe "#exhausted?" do
    it "returns false when max_uses is nil" do
      invite = build(:list_invite, max_uses: nil, uses_count: 100)
      expect(invite.exhausted?).to be false
    end

    it "returns false when uses_count < max_uses" do
      invite = build(:list_invite, max_uses: 5, uses_count: 3)
      expect(invite.exhausted?).to be false
    end

    it "returns true when uses_count >= max_uses" do
      invite = build(:list_invite, max_uses: 5, uses_count: 5)
      expect(invite.exhausted?).to be true
    end
  end

  describe "#usable?" do
    it "returns true when not expired and not exhausted" do
      invite = build(:list_invite, expires_at: nil, max_uses: nil)
      expect(invite.usable?).to be true
    end

    it "returns false when expired" do
      invite = build(:list_invite, expires_at: 1.day.ago)
      expect(invite.usable?).to be false
    end

    it "returns false when exhausted" do
      invite = build(:list_invite, max_uses: 1, uses_count: 1)
      expect(invite.usable?).to be false
    end
  end

  describe "#increment_uses!" do
    it "increments the uses_count" do
      invite = create(:list_invite, uses_count: 0)
      expect { invite.increment_uses! }.to change { invite.reload.uses_count }.from(0).to(1)
    end
  end

  describe "#invite_url" do
    it "returns the full invite URL" do
      invite = create(:list_invite)
      expect(invite.invite_url).to eq("https://focusmate.app/invite/#{invite.code}")
    end
  end

  describe "scopes" do
    describe ".active" do
      it "includes invites without expiration" do
        invite = create(:list_invite, expires_at: nil)
        expect(described_class.active).to include(invite)
      end

      it "includes invites with future expiration" do
        invite = create(:list_invite, expires_at: 1.day.from_now)
        expect(described_class.active).to include(invite)
      end

      it "excludes expired invites" do
        invite = create(:list_invite, expires_at: 1.day.ago)
        expect(described_class.active).not_to include(invite)
      end
    end

    describe ".available" do
      it "includes invites without usage limits" do
        invite = create(:list_invite, max_uses: nil)
        expect(described_class.available).to include(invite)
      end

      it "includes invites under the usage limit" do
        invite = create(:list_invite, max_uses: 5, uses_count: 3)
        expect(described_class.available).to include(invite)
      end

      it "excludes exhausted invites" do
        invite = create(:list_invite, max_uses: 5, uses_count: 5)
        expect(described_class.available).not_to include(invite)
      end
    end
  end
end
