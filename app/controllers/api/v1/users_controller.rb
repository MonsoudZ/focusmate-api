# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users/me
      def show
        render json: { user: UserSerializer.one(current_user) }, status: :ok
      end

      # PATCH /api/v1/users/me
      def update
        user = Users::ProfileUpdateService.call!(
          user: current_user,
          name: profile_params[:name],
          timezone: profile_params[:timezone]
        )

        render json: { user: UserSerializer.one(user) }, status: :ok
      end

      # PATCH /api/v1/users/me/password
      def update_password
        Users::PasswordChangeService.call!(
          user: current_user,
          current_password: password_change_params[:current_password],
          password: password_change_params[:password],
          password_confirmation: password_change_params[:password_confirmation]
        )

        render json: { message: "Password updated successfully" }, status: :ok
      end

      # DELETE /api/v1/users/me
      def destroy
        Users::AccountDeleteService.call!(
          user: current_user,
          password: account_delete_params[:password]
        )

        render json: { message: "Account deleted successfully" }, status: :ok
      end

      private

      def profile_params
        params.permit(:name, :timezone)
      end

      def password_change_params
        params.permit(:current_password, :password, :password_confirmation)
      end

      def account_delete_params
        params.permit(:password)
      end
    end
  end
end
