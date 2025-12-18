class ApplicationController < ActionController::API
  include Api::ErrorHandling
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
  rescue ActionView::Template::Error => e
    if e.message.include?("Error occurred while parsing request parameters")
      log_error(e, severity: :warn)
      render_bad_request("Invalid JSON format")
      false # Prevent further processing
    else
      raise e
    end
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

      # Devise-JWT uses "sub" by default for the resource identifier.
      user_id = payload["user_id"].presence || payload["sub"].presence

      if user_id.blank?
        render_unauthorized("Invalid token")
        return
      end

      # Enforce denylist revocation if we have a JTI claim (required for denylist).
      jti = payload["jti"].presence
      if jti.blank?
        render_unauthorized("Invalid token")
        return
      end

      if JwtDenylist.exists?(jti: jti)
        render_unauthorized("Token revoked")
        return
      end

      @current_user = User.find(user_id)
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
    log_error(exception, severity: :warn)
    render_bad_request("Invalid JSON format")
  end

  # Handle JSON parsing errors that occur before controller actions
  rescue_from ActionView::Template::Error do |exception|
    if exception.message.include?("Error occurred while parsing request parameters")
      log_error(exception, severity: :warn)
      render_bad_request("Invalid JSON format")
    else
      raise exception
    end
  end
end
