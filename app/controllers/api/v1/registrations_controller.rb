# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < Devise::RegistrationsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        if resource.persisted?
          render json: { user: user_json(resource) }, status: :created
        else
          render json: { error: "Validation failed", details: resource.errors.to_hash }, status: :unprocessable_entity
        end
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

