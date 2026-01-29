# frozen_string_literal: true

module Api
  module V1
    class AppleAuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        id_token = params[:id_token]

        Rails.logger.info("[AppleAuth] Received request, id_token present: #{id_token.present?}, params keys: #{params.keys}")
        Rails.logger.info("[AppleAuth] id_token first 50 chars: #{id_token.to_s[0..50]}...")

        return render_error("id_token is required", status: :bad_request) if id_token.blank?

        begin
          Rails.logger.info("[AppleAuth] Calling decoder...")
          claims = Auth::AppleTokenDecoder.decode(id_token)
          Rails.logger.info("[AppleAuth] Decoder returned: #{claims.present? ? 'claims present' : 'nil'}")
          return render_error("Invalid token", status: :unauthorized) unless claims

          apple_user_id = claims["sub"]
          email = claims["email"]
          name = params[:name] # Apple only sends name on first auth

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
          Rails.logger.error("[AppleAuth] Exception caught: #{e.class} - #{e.message}")
          Rails.error.report(e, handled: true, context: { action: "apple_sign_in" })
          render_error("Authentication failed", status: :unauthorized)
        end
      end
    end
  end
end
