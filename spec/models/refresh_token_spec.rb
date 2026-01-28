# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshToken, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:refresh_token) }

    it { is_expected.to validate_presence_of(:token_digest) }
    it { is_expected.to validate_uniqueness_of(:token_digest) }
    it { is_expected.to validate_presence_of(:jti) }
    it { is_expected.to validate_uniqueness_of(:jti) }
    it { is_expected.to validate_presence_of(:family) }
    it { is_expected.to validate_presence_of(:expires_at) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:active_token) { create(:refresh_token, user: user) }
    let!(:expired_token) { create(:refresh_token, :expired, user: user) }
    let!(:revoked_token) { create(:refresh_token, :revoked, user: user) }

    describe ".active" do
      it "returns only non-revoked, non-expired tokens" do
        expect(described_class.active).to contain_exactly(active_token)
      end
    end

    describe ".expired" do
      it "returns only expired tokens" do
        expect(described_class.expired).to contain_exactly(expired_token)
      end
    end

    describe ".revoked" do
      it "returns only revoked tokens" do
        expect(described_class.revoked).to contain_exactly(revoked_token)
      end
    end

    describe ".for_family" do
      let(:family) { "test-family" }
      let!(:family_token) { create(:refresh_token, user: user, family: family) }

      it "returns tokens in the specified family" do
        expect(described_class.for_family(family)).to contain_exactly(family_token)
      end
    end
  end

  describe "#active?" do
    it "returns true for non-revoked, non-expired token" do
      token = build(:refresh_token)
      expect(token).to be_active
    end

    it "returns false for revoked token" do
      token = build(:refresh_token, :revoked)
      expect(token).not_to be_active
    end

    it "returns false for expired token" do
      token = build(:refresh_token, :expired)
      expect(token).not_to be_active
    end
  end

  describe "#revoked?" do
    it "returns true when revoked_at is present" do
      token = build(:refresh_token, :revoked)
      expect(token).to be_revoked
    end

    it "returns false when revoked_at is nil" do
      token = build(:refresh_token)
      expect(token).not_to be_revoked
    end
  end

  describe "#expired?" do
    it "returns true when expires_at is in the past" do
      token = build(:refresh_token, :expired)
      expect(token).to be_expired
    end

    it "returns false when expires_at is in the future" do
      token = build(:refresh_token)
      expect(token).not_to be_expired
    end
  end

  describe "#revoke!" do
    it "sets revoked_at to current time" do
      token = create(:refresh_token)

      freeze_time do
        token.revoke!
        expect(token.reload.revoked_at).to eq(Time.current)
      end
    end

    it "does not update if already revoked" do
      original_time = 1.hour.ago
      token = create(:refresh_token, revoked_at: original_time)

      token.revoke!
      expect(token.reload.revoked_at).to be_within(1.second).of(original_time)
    end
  end
end
