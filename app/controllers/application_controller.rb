# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Api::ErrorHandling
  include ErrorResponseHelper
  include ErrorLoggingHelper

  before_action :force_json_format
  before_action :authenticate_user!

  # API-only app: don't let Devise write session location
  def store_location_for(_resource, _location)
    # no-op
  end

  private

  def force_json_format
    request.format = :json
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    log_error(e, severity: :warn)
    render_bad_request("Invalid JSON format")
  end

  rescue_from Pundit::NotAuthorizedError do |e|
    log_error(e, severity: :info)
    render_forbidden(e.message.presence || "Forbidden")
  end
end
