# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < Devise::RegistrationsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        if resource.persisted?
          render json: { user: UserSerializer.one(resource) }, status: :created
        else
          render json: {
            error: {
              code: "validation_error",
              message: "Validation failed",
              details: resource.errors.to_hash
            }
          }, status: :unprocessable_content
        end
      end
    end
  end
end
