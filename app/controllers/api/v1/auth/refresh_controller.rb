# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RefreshController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          token = refresh_params[:refresh_token]
          raise ApplicationError::TokenInvalid, "Refresh token is required" if token.blank?

          result = ::Auth::TokenService.refresh(token)

          render json: {
            user: UserSerializer.one(result[:user]),
            token: result[:access_token],
            refresh_token: result[:refresh_token]
          }, status: :ok
        end

        private

        def refresh_params
          params.permit(:refresh_token)
        end
      end
    end
  end
end
