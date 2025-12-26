# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users/me
      def show
        render json: { user: UserSerializer.one(current_user) }
      end

      # PATCH /api/v1/users/me
      def update
        user = Users::ProfileUpdateService.call!(
          user: current_user,
          name: params[:name],
          timezone: params[:timezone]
        )

        render json: { user: UserSerializer.one(user) }
      end

      # PUT /api/v1/users/me/password
      def update_password
        Users::PasswordChangeService.call!(
          user: current_user,
          current_password: params[:current_password],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        render json: { message: "Password updated successfully" }
      end

      # DELETE /api/v1/users/me
      def destroy
        Users::AccountDeleteService.call!(
          user: current_user,
          password: params[:password]
        )

        render json: { message: "Account deleted successfully" }
      end
    end
  end
end