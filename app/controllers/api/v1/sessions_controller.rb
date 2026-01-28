# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        pair = ::Auth::TokenService.issue_pair(resource)
        render json: {
          user: UserSerializer.one(resource),
          token: pair[:access_token],
          refresh_token: pair[:refresh_token]
        }, status: :ok
      end

      def respond_to_on_destroy
        raw = request.headers["X-Refresh-Token"].presence || params[:refresh_token]
        ::Auth::TokenService.revoke(raw) if raw
        head :no_content
      end
    end
  end
end
