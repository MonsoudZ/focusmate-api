# frozen_string_literal: true

module Api
  module V1
    class AppleAuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        id_token = params[:id_token]

        return render_error("id_token is required", status: :bad_request) if id_token.blank?

        begin
          claims = decode_apple_token(id_token)
          return render_error("Invalid token", status: :unauthorized) unless claims

          apple_user_id = claims["sub"]
          email = claims["email"]
          name = params[:name] # Apple only sends name on first auth

          # Use UserFinder service for consistent user lookup/creation
          user = UserFinder.find_or_create_by_apple(
            apple_user_id: apple_user_id,
            email: email,
            name: name
          )

          if user.persisted?
            pair = ::Auth::TokenService.issue_pair(user)
            render json: {
              user: UserSerializer.one(user),
              token: pair[:access_token],
              refresh_token: pair[:refresh_token]
            }, status: :ok
          else
            render_error(user.errors.full_messages.join(", "), status: :unprocessable_entity)
          end

        rescue StandardError => e
          Rails.logger.error "Apple Sign In error: #{e.message}"
          render_error("Authentication failed", status: :unauthorized)
        end
      end

      private

      def decode_apple_token(id_token)
        header_segment = id_token.to_s.split(".").first
        return nil if header_segment.blank?

        header = JSON.parse(Base64.decode64(header_segment))
        kid = header["kid"]

        # Fetch Apple's public keys
        apple_keys = fetch_apple_public_keys
        key_data = apple_keys.find { |k| k["kid"] == kid }

        return nil unless key_data

        # Build the public key
        jwk = JWT::JWK.new(key_data)

        # Decode and verify the token
        decoded = JWT.decode(
          id_token,
          jwk.public_key,
          true,
          {
            algorithm: "RS256",
            iss: "https://appleid.apple.com",
            verify_iss: true,
            aud: ENV["APPLE_BUNDLE_ID"],
            verify_aud: true
          }
        )

        decoded.first
      rescue JSON::ParserError, ArgumentError
        nil
      end

      def fetch_apple_public_keys
        Rails.cache.fetch("apple_auth_public_keys", expires_in: 5.minutes) do
          uri = URI("https://appleid.apple.com/auth/keys")
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                     open_timeout: 5, read_timeout: 5) do |http|
            http.get(uri.path)
          end
          JSON.parse(response.body)["keys"]
        end
      end
    end
  end
end
