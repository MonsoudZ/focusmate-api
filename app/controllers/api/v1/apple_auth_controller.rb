# frozen_string_literal: true

module Api
  module V1
    class AppleAuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        id_token = params[:id_token]

        return render_error("id_token is required", :bad_request) if id_token.blank?

        begin
          claims = decode_apple_token(id_token)
          return render_error("Invalid token", :unauthorized) unless claims

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
            token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
            render json: { user: UserSerializer.one(user), token: token }, status: :ok
          else
            render_error(user.errors.full_messages.join(", "), :unprocessable_entity)
          end

        rescue StandardError => e
          Rails.logger.error "Apple Sign In error: #{e.message}"
          render_error("Authentication failed", :unauthorized)
        end
      end

      private

      def decode_apple_token(id_token)
        # Decode without verification first to get the key id
        header = JSON.parse(Base64.decode64(id_token.split(".").first))
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
      end

      def fetch_apple_public_keys
        response = Net::HTTP.get(URI("https://appleid.apple.com/auth/keys"))
        JSON.parse(response)["keys"]
      end

      def render_error(message, status)
        render json: { error: { code: status.to_s, message: message } }, status: status
      end
    end
  end
end
