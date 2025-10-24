module Api
  module V1
    class ListSharesGlobalController < ApplicationController
      # No authentication required for email link acceptance
      skip_before_action :authenticate_user!, only: [ :accept ]

      # POST /api/v1/list_shares/accept (for email links)
      def accept
        token = params[:token]
        if token.blank?
          render json: { error: { message: "Token is required" } }, status: :bad_request
          return
        end

        share = ListShare.find_by!(invitation_token: token, status: "pending")

        if current_user.blank?
          # If user is not authenticated, find by email
          user = User.find_by(email: share.email)
          if user.nil?
            render json: { error: { message: "User not found" } }, status: :not_found
            return
          end
        else
          # If user is authenticated, use the authenticated user
          user = current_user
        end

        share.update!(
          user: user,
          status: "accepted",
          accepted_at: Time.current,
          invitation_token: nil
        )

        head :no_content
      end
    end
  end
end
