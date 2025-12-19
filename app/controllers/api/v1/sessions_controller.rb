# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        render json: { user: user_json(resource) }, status: :ok
      end

      def respond_to_on_destroy
        head :no_content
      end

      def user_json(user)
        {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          timezone: user.timezone
        }
      end
    end
  end
end

