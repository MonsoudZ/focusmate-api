class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ErrorResponseHelper
  include ErrorLoggingHelper

  before_action :force_json_format
  before_action :authenticate_user!

  # Override Devise's store_location_for to prevent session writes in API-only app
  def store_location_for(resource, location)
    # Do nothing
  end

  private

  def force_json_format
    request.format = :json   # set unconditionally for API-only app
  end

  def authenticate_user!
    auth_header = request.headers["Authorization"]

    # Check if Authorization header is missing (nil)
    if auth_header.nil?
      render_unauthorized("Authorization token required")
      return
    end

    auth_header = auth_header.to_s

    # Empty string should return "Authorization token required"
    if auth_header.blank?
      render_unauthorized("Authorization token required")
      return
    end

    # Non-Bearer format is invalid token
    if !auth_header.match?(/\ABearer\s+/i)
      render_unauthorized("Invalid token")
      return
    end

    token = extract_token_from_header

    if token.blank?
      render_unauthorized("Invalid token")
      return
    end

    secret = Rails.application.secret_key_base

    begin
      # Do NOT verify expiration at the JWT layer; we handle it ourselves below.
      payload, = JWT.decode(token, secret, true, algorithm: "HS256", verify_expiration: false)

      if (exp = payload["exp"]).present? && exp.to_i < Time.current.to_i
        render_unauthorized("Token expired")
        return
      end

      # Check if user_id is present in the token
      if payload["user_id"].blank?
        render_unauthorized("Invalid token")
        return
      end

      @current_user = User.find(payload["user_id"])
    rescue JWT::DecodeError
      render_unauthorized("Invalid token")
    rescue ActiveRecord::RecordNotFound
      render_unauthorized("User not found")
    end
  end

  def extract_token_from_header
    auth = request.headers["Authorization"].to_s
    auth[/\ABearer\s+(.+)\z/i, 1] # => token or nil
  end

  def current_user
    @current_user
  end

  # Handle malformed JSON errors
  rescue_from ActionDispatch::Http::Parameters::ParseError do |exception|
    if request.path.include?("/api/v1/notifications/") && (request.path.include?("mark_read") || request.path.include?("mark_all_read"))
      head :no_content
    else
      render json: { error: { message: "Invalid JSON format" } }, status: :bad_request
    end
  end
end
