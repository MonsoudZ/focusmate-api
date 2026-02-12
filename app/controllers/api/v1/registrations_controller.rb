# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      def create
        user = ::Auth::Register.call!(
          email: sign_up_params[:email],
          password: sign_up_params[:password],
          password_confirmation: sign_up_params[:password_confirmation],
          name: sign_up_params[:name],
          timezone: sign_up_params[:timezone]
        )

        pair = ::Auth::TokenService.issue_pair(user)
        render json: {
          user: UserSerializer.one(user),
          token: pair[:access_token],
          refresh_token: pair[:refresh_token]
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_error(e.record.errors.to_hash, message: "Registration failed")
      end

      private

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name, :timezone)
      end
    end
  end
end
