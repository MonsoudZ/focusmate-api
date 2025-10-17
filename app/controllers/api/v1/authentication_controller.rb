# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login, :register]

      # POST /api/v1/login
      # POST /api/v1/auth/sign_in
      def login
        user = User.find_by(email: params[:email])
        
        if user&.valid_password?(params[:password])
          token = generate_jwt_token(user)
          
          render json: {
            user: {
              id: user.id,
              email: user.email,
              name: user.name,
              role: user.role,
              timezone: user.timezone
            },
            token: token
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      # POST /api/v1/register
      # POST /api/v1/auth/sign_up
      def register
        user = User.new(user_params)
        
        if user.save
          token = generate_jwt_token(user)
          
          render json: {
            user: {
              id: user.id,
              email: user.email,
              name: user.name,
              role: user.role,
              timezone: user.timezone
            },
            token: token
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/profile
      def profile
        render json: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          role: current_user.role,
          timezone: current_user.timezone
        }
      end

      # DELETE /api/v1/logout
      # DELETE /api/v1/auth/sign_out
      def logout
        # With JWT, logout is handled client-side by deleting the token
        # Optional: Add token to blocklist if you implement one
        head :no_content
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name, :role, :timezone)
      end

      def generate_jwt_token(user)
        JWT.encode(
          {
            user_id: user.id,
            exp: 30.days.from_now.to_i
          },
          Rails.application.credentials.secret_key_base
        )
      end
    end
  end
end
