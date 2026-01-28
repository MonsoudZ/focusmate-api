# frozen_string_literal: true

module Api
  module V1
    class PasswordsController < Devise::PasswordsController
      respond_to :json

      # POST /api/v1/auth/password
      # Send reset password instructions
      def create
        self.resource = resource_class.send_reset_password_instructions(resource_params)

        render json: {
          message: "If an account exists with that email, password reset instructions have been sent."
        }, status: :ok
      end

      # PUT /api/v1/auth/password
      # Reset password with token
      def update
        self.resource = resource_class.reset_password_by_token(resource_params)

        if resource.errors.empty?
          render json: { message: "Password updated successfully" }, status: :ok
        else
          render json: {
            error: {
              code: "validation_error",
              message: "Password reset failed",
              details: resource.errors.to_hash
            }
          }, status: :unprocessable_entity
        end
      end

      private

      def resource_params
        params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
      end
    end
  end
end
