# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RefreshController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          result = ::Auth::TokenService.refresh(params[:refresh_token])

          render json: {
            user: UserSerializer.one(result[:user]),
            token: result[:access_token],
            refresh_token: result[:refresh_token]
          }, status: :ok
        end
      end
    end
  end
end
