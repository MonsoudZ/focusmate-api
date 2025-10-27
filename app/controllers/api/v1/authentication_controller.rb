# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :login, :register, :test_profile, :test_lists, :test_logout ]

      # POST /api/v1/login
      # POST /api/v1/auth/sign_in
      def login
        user = User.find_by(email: params[:email]&.strip&.downcase)

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
          render_unauthorized("Invalid email or password")
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
          render_validation_errors(user.errors)
        end
      end

      # GET /api/v1/profile
      def profile
        render json: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          role: current_user.role,
          timezone: current_user.timezone,
          created_at: current_user.created_at.iso8601,
          accessible_lists_count: current_user.owned_lists.count + current_user.lists.count
        }
      end

      # DELETE /api/v1/logout
      # DELETE /api/v1/auth/sign_out
      def logout
        # JWT logout is client-side; just return 204. Be explicit about content type to avoid to_sym on nil.
        head :no_content, content_type: "application/json"
      end

      # GET /api/v1/test-profile
      def test_profile
        user = User.first
        if user
          render json: {
            id: user.id,
            email: user.email,
            name: user.name,
            role: user.role,
            timezone: user.timezone
          }
        else
          render_not_found("Users")
        end
      end

      # GET /api/v1/test-lists
      def test_lists
        user = User.first
        if user
          lists = user.owned_lists
          render json: lists.map { |list|
            {
              id: list.id,
              name: list.name,
              description: list.description,
              created_at: list.created_at.iso8601
            }
          }
        else
          render_not_found("Users")
        end
      end

      # DELETE /api/v1/test-logout
      def test_logout
        head :no_content
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name, :timezone)
      end

      def generate_jwt_token(user)
        secret = Rails.application.secret_key_base
        JWT.encode(
          {
            user_id: user.id,
            jti: user.jti || SecureRandom.uuid,
            exp: 30.days.from_now.to_i
          },
          secret,
          "HS256"
        )
      end
    end
  end
end
