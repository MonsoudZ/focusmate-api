# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        token = request.env["warden-jwt_auth.token"]
        render json: { user: UserSerializer.one(resource), token: token }, status: :ok
      end

      def respond_to_on_destroy
        head :no_content
      end
    end
  end
end
