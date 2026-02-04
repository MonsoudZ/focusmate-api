# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtCleanupJob, type: :job do
  describe "#perform" do
    it "removes expired JWT tokens" do
      # Create expired tokens
      JwtDenylist.create!(jti: "expired-1", exp: 1.day.ago)
      JwtDenylist.create!(jti: "expired-2", exp: 1.hour.ago)

      # Create valid token
      JwtDenylist.create!(jti: "valid-1", exp: 1.day.from_now)

      expect { described_class.new.perform }.to change { JwtDenylist.count }.from(3).to(1)
    end

    it "returns count of removed tokens" do
      JwtDenylist.create!(jti: "expired-1", exp: 1.day.ago)
      JwtDenylist.create!(jti: "expired-2", exp: 1.hour.ago)

      result = described_class.new.perform

      expect(result).to eq(2)
    end

    it "handles empty denylist" do
      result = described_class.new.perform

      expect(result).to eq(0)
    end

    it "is enqueued to maintenance queue" do
      expect(described_class.new.queue_name).to eq("maintenance")
    end

    context "refresh token cleanup" do
      let(:user) { create(:user) }

      it "removes expired refresh tokens" do
        create(:refresh_token, user: user, expires_at: 1.day.ago)
        create(:refresh_token, user: user, expires_at: 1.hour.ago)
        create(:refresh_token, user: user) # active

        expect { described_class.new.perform }.to change { RefreshToken.count }.from(3).to(1)
      end

      it "removes revoked refresh tokens older than 7 days" do
        create(:refresh_token, user: user, revoked_at: 8.days.ago)
        create(:refresh_token, user: user, revoked_at: 10.days.ago)
        create(:refresh_token, user: user, revoked_at: 1.day.ago) # recent revoked, kept

        expect { described_class.new.perform }.to change { RefreshToken.count }.from(3).to(1)
      end

      it "keeps active refresh tokens" do
        create(:refresh_token, user: user)

        expect { described_class.new.perform }.not_to change { RefreshToken.count }
      end

      it "prunes inactive refresh-token families older than retention window" do
        family = SecureRandom.uuid
        create(:refresh_token, user: user, family: family, revoked_at: 5.days.ago)
        create(:refresh_token, user: user, family: family, revoked_at: 4.days.ago)

        expect {
          described_class.new.perform
        }.to change { RefreshToken.where(family: family).count }.from(2).to(0)
      end

      it "does not prune inactive families that are still within retention window" do
        family = SecureRandom.uuid
        create(:refresh_token, user: user, family: family, revoked_at: 1.day.ago)

        expect {
          described_class.new.perform
        }.not_to change { RefreshToken.where(family: family).count }
      end

      it "removes stale revoked tokens for active families and keeps active token" do
        family = SecureRandom.uuid
        stale_revoked = create(:refresh_token, user: user, family: family, revoked_at: 8.days.ago)
        active = create(:refresh_token, user: user, family: family)

        described_class.new.perform

        expect(RefreshToken.exists?(stale_revoked.id)).to be(false)
        expect(RefreshToken.exists?(active.id)).to be(true)
      end
    end

    it "tracks cleanup metrics without affecting job success" do
      allow(ApplicationMonitor).to receive(:track_metric)

      result = described_class.new.perform

      expect(result).to be_a(Integer)
      expect(ApplicationMonitor).to have_received(:track_metric).with("auth.jwt_denylist.remaining", kind_of(Numeric))
      expect(ApplicationMonitor).to have_received(:track_metric).with("auth.refresh_tokens.remaining", kind_of(Numeric))
      expect(ApplicationMonitor).to have_received(:track_metric).with("auth.refresh_inactive_families_pruned", kind_of(Numeric))
    end
  end
end
