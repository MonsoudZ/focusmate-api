# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::TokenService do
  let(:user) { create(:user) }

  describe ".issue_pair" do
    it "returns an access token and refresh token" do
      result = described_class.issue_pair(user)

      expect(result[:access_token]).to be_present
      expect(result[:refresh_token]).to be_present
    end

    it "creates a RefreshToken record" do
      expect { described_class.issue_pair(user) }.to change(RefreshToken, :count).by(1)
    end

    it "stores the refresh token as a SHA-256 digest" do
      result = described_class.issue_pair(user)
      digest = Digest::SHA256.hexdigest(result[:refresh_token])

      expect(RefreshToken.find_by(token_digest: digest)).to be_present
    end

    it "generates a valid JWT access token" do
      result = described_class.issue_pair(user)
      decoded = Warden::JWTAuth::TokenDecoder.new.call(result[:access_token])

      expect(decoded["sub"]).to eq(user.id.to_s)
    end

    it "retries refresh token creation on transient uniqueness collisions" do
      attempts = 0
      allow(RefreshToken).to receive(:create!).and_wrap_original do |original, *args|
        attempts += 1
        if attempts == 1
          raise ActiveRecord::RecordNotUnique, "duplicate key"
        end

        original.call(*args)
      end

      expect { described_class.issue_pair(user) }.to change(RefreshToken, :count).by(1)
      expect(attempts).to eq(2)
    end
  end

  describe ".refresh" do
    let(:pair) { described_class.issue_pair(user) }
    let(:raw_refresh) { pair[:refresh_token] }

    it "returns a new access token, refresh token, and user" do
      result = described_class.refresh(raw_refresh)

      expect(result[:access_token]).to be_present
      expect(result[:refresh_token]).to be_present
      expect(result[:user]).to eq(user)
    end

    it "returns different tokens than the original" do
      result = described_class.refresh(raw_refresh)

      expect(result[:access_token]).not_to eq(pair[:access_token])
      expect(result[:refresh_token]).not_to eq(raw_refresh)
    end

    it "revokes the old refresh token" do
      old_digest = Digest::SHA256.hexdigest(raw_refresh)
      described_class.refresh(raw_refresh)

      old_record = RefreshToken.find_by(token_digest: old_digest)
      expect(old_record).to be_revoked
    end

    it "sets replaced_by_jti on the old token" do
      old_digest = Digest::SHA256.hexdigest(raw_refresh)
      described_class.refresh(raw_refresh)

      old_record = RefreshToken.find_by(token_digest: old_digest)
      expect(old_record.replaced_by_jti).to be_present
    end

    it "preserves the token family on rotation" do
      old_digest = Digest::SHA256.hexdigest(raw_refresh)
      old_family = RefreshToken.find_by(token_digest: old_digest).family

      result = described_class.refresh(raw_refresh)
      new_digest = Digest::SHA256.hexdigest(result[:refresh_token])
      new_family = RefreshToken.find_by(token_digest: new_digest).family

      expect(new_family).to eq(old_family)
    end

    it "locks the refresh token row while rotating" do
      expect(RefreshToken).to receive(:lock).with("FOR UPDATE").and_call_original

      described_class.refresh(raw_refresh)
    end

    context "reuse detection" do
      context "within grace period (race condition)" do
        it "raises TokenAlreadyRefreshed when token was just rotated" do
          # Use the token once (valid rotation)
          described_class.refresh(raw_refresh)

          # Attempt to reuse within grace period (simulating parallel request race)
          expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenAlreadyRefreshed)
        end

        it "tracks a grace-period reuse metric" do
          allow(ApplicationMonitor).to receive(:track_metric)

          described_class.refresh(raw_refresh)
          expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenAlreadyRefreshed)

          expect(ApplicationMonitor).to have_received(:track_metric).with(
            "auth.refresh_token_reuse",
            1,
            tags: { outcome: "grace" }
          )
        end

        it "does NOT revoke the family during grace period" do
          # Rotate the token
          result = described_class.refresh(raw_refresh)

          # Reuse within grace period - should NOT revoke family
          expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenAlreadyRefreshed)

          # The new token should still be valid (not revoked)
          new_digest = Digest::SHA256.hexdigest(result[:refresh_token])
          new_record = RefreshToken.find_by(token_digest: new_digest)
          expect(new_record).not_to be_revoked
        end
      end

      context "after grace period (real reuse attack)" do
        it "raises TokenReused when a revoked token is presented after grace period" do
          # Use the token once (valid rotation)
          described_class.refresh(raw_refresh)

          # Simulate time passing beyond grace period
          travel 15.seconds do
            expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenReused)
          end
        end

        it "emits anomaly telemetry for reuse detection" do
          allow(ApplicationMonitor).to receive(:track_metric)
          allow(ApplicationMonitor).to receive(:alert)

          described_class.refresh(raw_refresh)

          travel 15.seconds do
            expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenReused)
          end

          expect(ApplicationMonitor).to have_received(:track_metric).with(
            "auth.refresh_token_reuse",
            1,
            tags: { outcome: "attack" }
          )
          expect(ApplicationMonitor).to have_received(:alert).with(
            "Refresh token reuse detected",
            severity: :warning,
            user_id: user.id,
            family: kind_of(String),
            revoked_tokens: kind_of(Integer)
          )
        end

        it "revokes the entire family when reuse is detected after grace period" do
          # Rotate the token
          result = described_class.refresh(raw_refresh)

          # Reuse after grace period — should revoke the whole family
          travel 15.seconds do
            expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenReused)
          end

          new_digest = Digest::SHA256.hexdigest(result[:refresh_token])
          new_record = RefreshToken.find_by(token_digest: new_digest)
          expect(new_record).to be_revoked
        end

        it "continues security response when observability hooks fail" do
          allow(ApplicationMonitor).to receive(:track_metric).and_raise(StandardError.new("metrics down"))
          allow(ApplicationMonitor).to receive(:alert).and_raise(StandardError.new("alerts down"))

          described_class.refresh(raw_refresh)

          travel 15.seconds do
            expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenReused)
          end
        end
      end
    end

    context "with expired token" do
      it "raises TokenExpired" do
        # Issue then expire the token
        digest = Digest::SHA256.hexdigest(raw_refresh)
        RefreshToken.find_by(token_digest: digest).update!(expires_at: 1.hour.ago)

        expect { described_class.refresh(raw_refresh) }.to raise_error(ApplicationError::TokenExpired)
      end
    end

    context "with invalid token" do
      it "raises TokenInvalid for a blank token" do
        expect { described_class.refresh("") }.to raise_error(ApplicationError::TokenInvalid)
      end

      it "raises TokenInvalid for non-string token payloads" do
        expect { described_class.refresh(123) }.to raise_error(ApplicationError::TokenInvalid)
      end

      it "raises TokenInvalid for excessively long tokens" do
        expect { described_class.refresh("a" * 513) }.to raise_error(ApplicationError::TokenInvalid)
      end

      it "raises TokenInvalid for an unknown token" do
        expect { described_class.refresh("nonexistent-token") }.to raise_error(ApplicationError::TokenInvalid)
      end
    end
  end

  describe ".revoke" do
    it "revokes the specified token" do
      pair = described_class.issue_pair(user)
      described_class.revoke(pair[:refresh_token])

      digest = Digest::SHA256.hexdigest(pair[:refresh_token])
      expect(RefreshToken.find_by(token_digest: digest)).to be_revoked
    end

    it "does nothing for a blank token" do
      expect { described_class.revoke("") }.not_to raise_error
    end

    it "does nothing for non-string token payloads" do
      expect { described_class.revoke(123) }.not_to raise_error
    end

    it "does nothing for excessively long token payloads" do
      expect { described_class.revoke("a" * 513) }.not_to raise_error
    end

    it "does nothing for an unknown token" do
      expect { described_class.revoke("nonexistent") }.not_to raise_error
    end
  end

  describe ".revoke_all_for_user" do
    it "revokes all active tokens for the user" do
      3.times { described_class.issue_pair(user) }

      described_class.revoke_all_for_user(user)

      expect(user.refresh_tokens.active.count).to eq(0)
      expect(user.refresh_tokens.revoked.count).to eq(3)
    end

    it "does not affect other users' tokens" do
      other_user = create(:user)
      described_class.issue_pair(user)
      described_class.issue_pair(other_user)

      described_class.revoke_all_for_user(user)

      expect(other_user.refresh_tokens.active.count).to eq(1)
    end
  end

  describe "active refresh token limits" do
    context "token cap enforcement" do
      before do
        allow(described_class).to receive(:max_active_refresh_tokens).and_return(2)
        allow(described_class).to receive(:max_active_refresh_families).and_return(10)
      end

      it "revokes the oldest active token when cap is exceeded" do
        first = described_class.issue_pair(user)
        second = described_class.issue_pair(user)
        third = described_class.issue_pair(user)

        first_record = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(first[:refresh_token]))
        second_record = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(second[:refresh_token]))
        third_record = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(third[:refresh_token]))

        expect(first_record).to be_revoked
        expect(second_record).not_to be_revoked
        expect(third_record).not_to be_revoked
      end

      it "keeps latest token issuance working when eviction telemetry fails" do
        described_class.issue_pair(user)
        allow(ApplicationMonitor).to receive(:track_metric).and_raise(StandardError.new("metrics down"))

        expect { described_class.issue_pair(user) }.not_to raise_error
        expect(user.refresh_tokens.active.count).to eq(2)
      end
    end

    context "family cap enforcement" do
      before do
        allow(described_class).to receive(:max_active_refresh_tokens).and_return(10)
        allow(described_class).to receive(:max_active_refresh_families).and_return(2)
      end

      it "revokes the oldest active family when cap is exceeded" do
        first = described_class.issue_pair(user)
        second = described_class.issue_pair(user)
        third = described_class.issue_pair(user)

        family_one = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(first[:refresh_token])).family
        family_two = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(second[:refresh_token])).family
        family_three = RefreshToken.find_by(token_digest: Digest::SHA256.hexdigest(third[:refresh_token])).family

        active_families = user.refresh_tokens.active.distinct.pluck(:family)
        expect(active_families).to contain_exactly(family_two, family_three)
        expect(active_families).not_to include(family_one)
      end
    end
  end
end
