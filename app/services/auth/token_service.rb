# frozen_string_literal: true

module Auth
  class TokenService
    REFRESH_TOKEN_LIFETIME = 30.days
    REFRESH_TOKEN_BYTE_LENGTH = 32
    MAX_REFRESH_TOKEN_LENGTH = 512
    MAX_REFRESH_TOKEN_CREATE_ATTEMPTS = 3
    REFRESH_REUSE_GRACE_PERIOD = 10.seconds
    REFRESH_REUSE_METRIC = "auth.refresh_token_reuse".freeze

    class TokenReuseDetected < StandardError
      attr_reader :family, :user_id

      def initialize(family:, user_id:)
        @family = family
        @user_id = user_id
        super(family)
      end
    end

    class << self
      # Issue a new access + refresh token pair for the user.
      #
      # @param user [User]
      # @return [Hash] { access_token:, refresh_token: }
      def issue_pair(user)
        access_token = encode_access_token(user)
        raw_refresh, record = create_refresh_token(user)
        observe_refresh_issue(user_id: user.id, family: record.family)

        { access_token: access_token, refresh_token: raw_refresh }
      end

      # Validate the refresh token, rotate it (revoke old, issue new), and return a new pair.
      #
      # @param raw_refresh_token [String] the opaque refresh token
      # @return [Hash] { access_token:, refresh_token:, user: }
      # @raise [ApplicationError::TokenInvalid, ApplicationError::TokenExpired, ApplicationError::TokenReused]
      def refresh(raw_refresh_token)
        token = normalize_refresh_token(raw_refresh_token)
        raise ApplicationError::TokenInvalid, "Refresh token is required" unless token

        digest = token_digest(token)
        begin
          ActiveRecord::Base.transaction do
            # Lock the token row to make rotation atomic across concurrent requests.
            # This prevents two parallel refreshes from minting two successor tokens.
            record = RefreshToken.lock("FOR UPDATE").find_by(token_digest: digest)

            raise ApplicationError::TokenInvalid, "Invalid refresh token" unless record

            # Reuse detection: if the token was already revoked, someone may be replaying it.
            # However, check for race conditions first - parallel requests can cause
            # multiple refresh attempts with the same token.
            if record.revoked?
              # Grace period: if token was rotated within last 10 seconds, this is likely
              # a race condition (parallel 401s triggering multiple refreshes), not an attack.
              # Don't revoke the family - the first refresh's tokens should remain valid.
              if record.revoked_at > REFRESH_REUSE_GRACE_PERIOD.ago
                observe_refresh_reuse_within_grace(user_id: record.user_id, family: record.family)
                raise ApplicationError::TokenAlreadyRefreshed, "Token was already refreshed"
              end

              # Token was revoked more than 10 seconds ago - this is a real reuse attack.
              # Revoke the family after we release the lock/transaction.
              raise TokenReuseDetected.new(family: record.family, user_id: record.user_id)
            end

            raise ApplicationError::TokenExpired, "Refresh token has expired" if record.expired?

            user = record.user
            raw_refresh, new_record = create_refresh_token(user, family: record.family)
            record.update!(revoked_at: Time.current, replaced_by_jti: new_record.jti)
            observe_refresh_rotation(user_id: user.id, family: record.family, previous_jti: record.jti, new_jti: new_record.jti)

            {
              access_token: encode_access_token(user),
              refresh_token: raw_refresh,
              user: user
            }
          end
        rescue TokenReuseDetected => e
          revoked_count = revoke_family(e.family)
          observe_refresh_reuse_attack(user_id: e.user_id, family: e.family, revoked_tokens: revoked_count)
          raise ApplicationError::TokenReused, "Refresh token reuse detected"
        end
      end

      # Revoke a specific refresh token (e.g. on sign-out).
      #
      # @param raw_refresh_token [String]
      def revoke(raw_refresh_token)
        token = normalize_refresh_token(raw_refresh_token)
        return unless token

        digest = token_digest(token)
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
        attempts = 0
        token_family = family || SecureRandom.uuid

        begin
          raw = SecureRandom.urlsafe_base64(REFRESH_TOKEN_BYTE_LENGTH)
          jti = SecureRandom.uuid

          record = RefreshToken.create!(
            user: user,
            token_digest: token_digest(raw),
            jti: jti,
            family: token_family,
            expires_at: REFRESH_TOKEN_LIFETIME.from_now
          )

          [ raw, record ]
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          attempts += 1
          raise unless retryable_token_collision?(e) && attempts < MAX_REFRESH_TOKEN_CREATE_ATTEMPTS

          retry
        end
      end

      def token_digest(raw_token)
        Digest::SHA256.hexdigest(raw_token)
      end

      def normalize_refresh_token(raw_token)
        return nil unless raw_token.is_a?(String)

        token = raw_token.strip
        return nil if token.blank?
        return nil if token.length > MAX_REFRESH_TOKEN_LENGTH

        token
      end

      def retryable_token_collision?(error)
        return true if error.is_a?(ActiveRecord::RecordNotUnique)
        return false unless error.is_a?(ActiveRecord::RecordInvalid)

        record = error.record
        return false unless record.respond_to?(:errors)

        record.errors.added?(:token_digest, :taken) || record.errors.added?(:jti, :taken)
      end

      def revoke_family(family)
        RefreshToken.for_family(family).active.update_all(revoked_at: Time.current)
      end

      def observe_refresh_issue(user_id:, family:)
        Rails.logger.info(
          event: "auth_refresh_token_issued",
          user_id: user_id,
          family: family
        )
      end

      def observe_refresh_rotation(user_id:, family:, previous_jti:, new_jti:)
        Rails.logger.info(
          event: "auth_refresh_token_rotated",
          user_id: user_id,
          family: family,
          previous_jti: previous_jti,
          new_jti: new_jti
        )
      end

      def observe_refresh_reuse_within_grace(user_id:, family:)
        Rails.logger.warn(
          event: "auth_refresh_token_reuse_within_grace",
          user_id: user_id,
          family: family
        )

        with_observability do
          ApplicationMonitor.track_metric(REFRESH_REUSE_METRIC, 1, tags: { outcome: "grace" })
        end
      end

      def observe_refresh_reuse_attack(user_id:, family:, revoked_tokens:)
        Rails.logger.error(
          event: "auth_refresh_token_reuse_detected",
          user_id: user_id,
          family: family,
          revoked_tokens: revoked_tokens
        )

        with_observability do
          ApplicationMonitor.track_metric(REFRESH_REUSE_METRIC, 1, tags: { outcome: "attack" })
          ApplicationMonitor.alert(
            "Refresh token reuse detected",
            severity: :warning,
            user_id: user_id,
            family: family,
            revoked_tokens: revoked_tokens
          )
        end
      end

      def with_observability
        yield
      rescue StandardError => e
        Rails.logger.error(
          event: "auth_token_observability_failed",
          error_class: e.class.name,
          error_message: e.message
        )
      end
    end
  end
end
