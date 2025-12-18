# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[login register]

      # POST /api/v1/auth/sign_in
      def login
        user = Auth::Login.call!(
          email: auth_params[:email],
          password: auth_params[:password]
        )

        sign_in(user, store: false)

        render json: {
          user: UserSerializer.one(user),
          token: jwt_token!
        }, status: :ok
      end

      # POST /api/v1/auth/sign_up
      def register
        user = Auth::Register.call!(**register_params.to_h.symbolize_keys)

        sign_in(user, store: false)

        render json: {
          user: UserSerializer.one(user),
          token: jwt_token!
        }, status: :created
      end

      # GET /api/v1/profile
      def profile
        u = current_user

        render json: {
          user: UserSerializer.one(u).merge(
            created_at: u.created_at.iso8601,
            accessible_lists_count: accessible_lists_count(u)
          )
        }, status: :ok
      end

      # DELETE /api/v1/logout  (and/or /api/v1/auth/sign_out)
      def logout
        sign_out(:user)
        head :no_content
      end

      private

      def jwt_token!
        request.env.fetch("warden-jwt_auth.token")
      end

      def auth_params
        params.require(:authentication).permit(:email, :password)
      end

      # Allow sign_up via {authentication:{...}} or {user:{...}}
      def register_params
        key = params[:authentication].present? ? :authentication : :user
        params.require(key).permit(:email, :password, :password_confirmation, :name, :timezone)
      end

      def accessible_lists_count(user)
        # Avoid N+1 / heavy loading
        user.owned_lists.count + user.lists.count
      end
    end
  end
end
