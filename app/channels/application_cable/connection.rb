# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user!
      log_connection_established
    end

    def disconnect
      log_connection_disconnected
    end

    private

    def find_user!
      token = extract_token

      if token.blank?
        log_connection_rejected("No token provided")
        reject_unauthorized_connection
        return
      end

      begin
        payload = decode_jwt_token(token)
        return if payload.nil?

        user_id = payload["user_id"]

        if user_id.blank?
          log_connection_rejected("Invalid token: missing user_id")
          reject_unauthorized_connection
          return
        end

        # Check token expiration
        if token_expired?(payload)
          log_connection_rejected("Token expired")
          reject_unauthorized_connection
          return
        end

        # Check if token is blacklisted
        if token_blacklisted?(token)
          log_connection_rejected("Token blacklisted")
          reject_unauthorized_connection
          return
        end

        user = User.find(user_id)

        # Additional user validation
        unless user_active?(user)
          log_connection_rejected("User account inactive")
          reject_unauthorized_connection
          return
        end

        log_connection_authorized(user)
        user

      rescue JWT::DecodeError => e
        log_connection_rejected("JWT decode error: #{e.message}")
        reject_unauthorized_connection
      rescue ActiveRecord::RecordNotFound => e
        log_connection_rejected("User not found: #{e.message}")
        reject_unauthorized_connection
      rescue => e
        log_connection_rejected("Unexpected error: #{e.message}")
        reject_unauthorized_connection
      end
    end

    def extract_token
      # Try multiple token sources for flexibility
      token = request.params["token"] ||
              request.headers["Authorization"]&.split&.last ||
              request.headers["X-Auth-Token"] ||
              request.headers["X-API-Token"]

      # Clean up token (remove Bearer prefix if present)
      token&.gsub(/^Bearer\s+/i, "")
    end

    def decode_jwt_token(token)
      JWT.decode(
        token,
        Rails.application.credentials.secret_key_base,
        true,
        { algorithm: "HS256" }
      ).first
    rescue JWT::ExpiredSignature
      log_connection_rejected("Token signature expired")
      nil
    rescue JWT::InvalidIssuerError
      log_connection_rejected("Invalid token issuer")
      nil
    rescue JWT::InvalidAudienceError
      log_connection_rejected("Invalid token audience")
      nil
    rescue JWT::InvalidIatError
      log_connection_rejected("Invalid token issued at")
      nil
    rescue JWT::InvalidJtiError
      log_connection_rejected("Invalid token JTI")
      nil
    rescue JWT::DecodeError => e
      log_connection_rejected("JWT decode error: #{e.message}")
      nil
    end

    def token_expired?(payload)
      return false unless payload["exp"]

      payload["exp"] < Time.current.to_i
    end

    def token_blacklisted?(token)
      # Check if token is in the JWT denylist
      return false unless defined?(JwtDenylist)

      JwtDenylist.exists?(jti: extract_jti_from_token(token))
    end

    def extract_jti_from_token(token)
      # Extract JTI from token without full decode for performance
      begin
        decoded = JWT.decode(token, nil, false)
        decoded.first["jti"]
      rescue
        nil
      end
    end

    def user_active?(user)
      # Add any additional user validation logic here
      user.present? && !user.respond_to?(:active?) || user.active?
    end

    def log_connection_established
      Rails.logger.info "[WebSocket] Connection established for user ##{current_user&.id} from #{request.remote_ip}"
    end

    def log_connection_disconnected
      Rails.logger.info "[WebSocket] Connection disconnected for user ##{current_user&.id} from #{request.remote_ip}"
    end

    def log_connection_authorized(user)
      Rails.logger.info "[WebSocket] User authorized: ##{user.id} (#{user.email}) from #{request.remote_ip}"
    end

    def log_connection_rejected(reason)
      Rails.logger.warn "[WebSocket] Connection rejected: #{reason} from #{request.remote_ip}"
    end
  end
end
