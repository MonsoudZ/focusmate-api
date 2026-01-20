# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate_user!

      def create
        user = Auth::Register.call!(
          email: sign_up_params[:email],
          password: sign_up_params[:password],
          password_confirmation: sign_up_params[:password_confirmation],
          name: sign_up_params[:name],
          timezone: sign_up_params[:timezone]
        )

        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        render json: { user: UserSerializer.one(user), token: token }, status: :created
      rescue Auth::Register::BadRequest => e
        render json: { error: { message: e.message } }, status: :bad_request
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          error: {
            code: "validation_error",
            message: "Registration failed",
            details: e.record.errors.to_hash
          }
        }, status: :unprocessable_entity
      end

      private

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name, :timezone)
      end
    end
  end
end


