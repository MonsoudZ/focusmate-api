# frozen_string_literal: true

module Auth
  class TokenService
    class TokenInvalid < StandardError; end
    class TokenExpired < StandardError; end
    class TokenRevoked < StandardError; end
    class TokenReused < StandardError; end

    REFRESH_TOKEN_LIFETIME = 30.days
    REFRESH_TOKEN_BYTE_LENGTH = 32

    class << self
      # Issue a new access + refresh token pair for the user.
      #
      # @param user [User]
      # @return [Hash] { access_token:, refresh_token: }
      def issue_pair(user)
        access_token = encode_access_token(user)
        raw_refresh, _record = create_refresh_token(user)

        { access_token: access_token, refresh_token: raw_refresh }
      end

      # Validate the refresh token, rotate it (revoke old, issue new), and return a new pair.
      #
      # @param raw_refresh_token [String] the opaque refresh token
      # @return [Hash] { access_token:, refresh_token:, user: }
      # @raise [TokenInvalid, TokenExpired, TokenRevoked, TokenReused]
      def refresh(raw_refresh_token)
        raise TokenInvalid, "Refresh token is required" if raw_refresh_token.blank?

        digest = token_digest(raw_refresh_token)
        record = RefreshToken.find_by(token_digest: digest)

        raise TokenInvalid, "Invalid refresh token" unless record

        # Reuse detection: if the token was already revoked, someone is replaying it.
        # Revoke the entire family to protect the user.
        if record.revoked?
          revoke_family(record.family)
          raise TokenReused, "Refresh token reuse detected"
        end

        raise TokenExpired, "Refresh token has expired" if record.expired?

        # Rotate: revoke old token + issue new pair in a transaction
        user = record.user
        new_pair = nil

        ActiveRecord::Base.transaction do
          raw_refresh, new_record = create_refresh_token(user, family: record.family)
          record.update!(revoked_at: Time.current, replaced_by_jti: new_record.jti)

          new_pair = {
            access_token: encode_access_token(user),
            refresh_token: raw_refresh,
            user: user
          }
        end

        new_pair
      end

      # Revoke a specific refresh token (e.g. on sign-out).
      #
      # @param raw_refresh_token [String]
      def revoke(raw_refresh_token)
        return if raw_refresh_token.blank?

        digest = token_digest(raw_refresh_token)
        record = RefreshToken.find_by(token_digest: digest)
        record&.revoke!
      end

      # Revoke all active refresh tokens for a user (e.g. password change, account compromise).
      #
      # @param user [User]
      def revoke_all_for_user(user)
        user.refresh_tokens.active.update_all(revoked_at: Time.current)
      end

      private

      def encode_access_token(user)
        Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      end

      def create_refresh_token(user, family: nil)
        raw = SecureRandom.urlsafe_base64(REFRESH_TOKEN_BYTE_LENGTH)
        jti = SecureRandom.uuid
        family ||= SecureRandom.uuid

        record = RefreshToken.create!(
          user: user,
          token_digest: token_digest(raw),
          jti: jti,
          family: family,
          expires_at: REFRESH_TOKEN_LIFETIME.from_now
        )

        [ raw, record ]
      end

      def token_digest(raw_token)
        Digest::SHA256.hexdigest(raw_token)
      end

      def revoke_family(family)
        RefreshToken.for_family(family).active.update_all(revoked_at: Time.current)
      end
    end
  end
end
