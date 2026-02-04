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
        raw = request.headers["X-Refresh-Token"].presence || sign_out_params[:refresh_token]
        token = normalize_refresh_token(raw)
        ::Auth::TokenService.revoke(token) if token
        head :no_content
      end

      def sign_out_params
        params.permit(:refresh_token)
      end

      def normalize_refresh_token(value)
        return nil unless value.is_a?(String)

        token = value.strip
        return nil if token.blank?
        return nil if token.length > ::Auth::TokenService::MAX_REFRESH_TOKEN_LENGTH

        token
      end
    end
  end
end
