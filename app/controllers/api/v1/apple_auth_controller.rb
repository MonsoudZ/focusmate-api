# frozen_string_literal: true

module Api
  module V1
    class AppleAuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        id_token = apple_auth_params[:id_token]
        return render_error("id_token is required", status: :bad_request) if id_token.blank?

        begin
          claims = ::Auth::AppleTokenDecoder.decode(id_token)
          return render_error("Invalid token", status: :unauthorized) unless claims

          apple_user_id = claims["sub"]
          email = claims["email"]
          name = apple_auth_params[:name] # Apple only sends name on first auth

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
            # Return generic message to prevent user enumeration via validation
            # errors (e.g. "Email has already been taken" leaks account existence).
            Rails.logger.error("[AppleAuth] User creation failed: #{user.errors.full_messages.join(', ')}")
            render_error("Authentication failed", status: :unprocessable_content)
          end

        rescue StandardError => e
          Rails.logger.error("[AppleAuth] Exception caught: #{e.class} - #{e.message}")
          Rails.error.report(e, handled: true, context: { action: "apple_sign_in" })
          render_error("Authentication failed", status: :unauthorized)
        end
      end

      private

      def apple_auth_params
        params.permit(:id_token, :name)
      end
    end
  end
end
