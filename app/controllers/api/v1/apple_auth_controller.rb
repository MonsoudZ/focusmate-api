# frozen_string_literal: true

module Api
  module V1
    class AppleAuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        id_token = params[:id_token]
        
        return render_error("id_token is required", :bad_request) if id_token.blank?

        begin
          # Decode and verify Apple's identity token
          claims = decode_apple_token(id_token)
          
          return render_error("Invalid token", :unauthorized) unless claims

          apple_user_id = claims["sub"]
          email = claims["email"]
          name = params[:name] # Apple only sends name on first auth

          # Find or create user
          user = find_or_create_user(apple_user_id, email, name)

          if user.persisted?
            # Generate JWT token
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

      def find_or_create_user(apple_user_id, email, name)
        # First try to find by Apple ID
        user = User.find_by(apple_user_id: apple_user_id)
        return user if user

        # Then try to find by email and link Apple ID
        if email.present?
          user = User.find_by(email: email)
          if user
            user.update(apple_user_id: apple_user_id)
            return user
          end
        end

        # Create new user
        User.create(
          email: email || "#{apple_user_id}@privaterelay.appleid.com",
          apple_user_id: apple_user_id,
          name: name,
          password: SecureRandom.hex(16)
        )
      end

      def render_error(message, status)
        render json: { error: { code: status.to_s, message: message } }, status: status
      end
    end
  end
end
