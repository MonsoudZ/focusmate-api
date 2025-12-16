# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApplicationController
      # Only these are public
      skip_before_action :authenticate_user!, only: %i[login register]

      # Skip authentication for test endpoints in dev/test environments
      if Rails.env.development? || Rails.env.test?
        skip_before_action :authenticate_user!, only: %i[test_profile test_lists test_logout]
      end

      # POST /api/v1/auth/sign_in
      def login
        creds = auth_params # { email, password }
        user  = User.find_by(email: creds[:email]&.strip&.downcase)

        unless user&.valid_password?(creds[:password])
          return unauth!("Invalid email or password")
        end

        # Let Devise-JWT handle token dispatch via Warden.
        # If the Authorization header is missing, that is a configuration bug, not
        # something we should patch with manual token generation.
        sign_in(user, store: false)

        render json: auth_payload(user), status: :ok
      end

      # POST /api/v1/auth/sign_up
      def register
        # Accept either {authentication:{...}} or {user:{...}} for convenience
        attrs = auth_params_flexible
        user = User.new(
          email:                 attrs[:email],
          password:              attrs[:password],
          password_confirmation: attrs[:password_confirmation],
          name:                  attrs[:name],
          timezone:              attrs[:timezone]
        )

        if user.save
          # Sign in to trigger JWT dispatch for newly registered users (if configured).
          sign_in(user, store: false)
          render json: auth_payload(user), status: :created
        else
          render json: { code: "validation_error", message: "Validation failed", details: user.errors.to_hash },
                 status: :unprocessable_content
        end
      end

      # GET /api/v1/profile
      def profile
        u = current_user
        render json: {
          id:        u.id,
          email:     u.email,
          name:      u.name,
          role:      u.role,
          timezone:  u.timezone,
          created_at: u.created_at.iso8601,
          accessible_lists_count: u.owned_lists.count + u.lists.count
        }
      end

      # DELETE /api/v1/logout and /api/v1/auth/sign_out
      def logout
        # Let Devise-JWT handle revocation (via jwt.revocation_requests),
        # and explicitly sign_out so the revocation strategy is invoked.
        sign_out(current_user) if current_user
        head :no_content
      end

      # ----- DEV/TEST helpers (do NOT expose in prod) -----
      if Rails.env.development? || Rails.env.test?
        # GET /api/v1/test-profile
        def test_profile
          user = User.first or return render json: { code: "not_found", message: "No users" }, status: :not_found
          render json: { id: user.id, email: user.email, name: user.name, role: user.role, timezone: user.timezone }
        end

        # GET /api/v1/test-lists
        def test_lists
          user = User.first or return render json: { code: "not_found", message: "No users" }, status: :not_found
          render json: user.owned_lists.map { |l|
            { id: l.id, name: l.name, description: l.description, created_at: l.created_at.iso8601 }
          }
        end

        # DELETE /api/v1/test-logout
        def test_logout
          head :no_content
        end
      end

      private

      # Standardize response body for SwiftUI
      def auth_payload(user)
        {
          user: {
            id:       user.id,
            email:    user.email,
            name:     user.name,
            role:     user.role,
            timezone: user.timezone
          }
        }
      end

      # Enforce consistent param shape: {authentication:{email,password}}
      def auth_params
        params.require(:authentication).permit(:email, :password)
      end

      # Allow sign_up via {authentication:{...}} or {user:{...}}
      def auth_params_flexible
        if params[:authentication].present?
          params.require(:authentication).permit(:email, :password, :password_confirmation, :name, :timezone)
        else
          params.require(:user).permit(:email, :password, :password_confirmation, :name, :timezone)
        end
      end

      # Uniform 401 with WWW-Authenticate for clients
      def unauth!(message)
        response.set_header("WWW-Authenticate", 'Bearer realm="Application"')
        render json: { error: { message: message } }, status: :unauthorized
      end
    end
  end
end
