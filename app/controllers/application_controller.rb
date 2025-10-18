class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ErrorResponseHelper

  before_action :authenticate_user!

  # Override Devise's store_location_for to prevent session writes in API-only app
  def store_location_for(resource, location)
    # Do nothing
  end

  private

  def authenticate_user!
    token = extract_token_from_header

    if token.blank?
      render_unauthorized("Authorization token required")
      return
    end

    begin
      payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: "HS256")
      user_id = payload.first["user_id"]
      @current_user = User.find(user_id)
    rescue JWT::DecodeError => e
      render_unauthorized("Invalid token")
    rescue ActiveRecord::RecordNotFound
      render_unauthorized("User not found")
    end
  end

  def extract_token_from_header
    request.headers["Authorization"]&.split(" ")&.last
  end

  def current_user
    @current_user
  end
end
