# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :force_json_format
  before_action :authenticate_user!

  # API-only app: don't let Devise write session location
  def store_location_for(_resource, _location)
    # no-op
  end

  # ---- Devise/Warden auth (API) ---------------------------------------------
  #
  # devise-jwt authenticates Bearer tokens via Warden.
  # This keeps auth "Devise-only" and avoids hand-parsing JWTs.
  #
  def authenticate_user!
    warden.authenticate!(scope: :user)
  rescue ::Warden::NotAuthenticated
    render json: { error: { message: "Unauthorized" } }, status: :unauthorized
  end

  def current_user
    warden.user(:user)
  end

  def user_signed_in?
    warden.authenticated?(:user)
  end

  # Your AuthenticationController calls sign_in/sign_out.
  def sign_in(resource, scope: :user, **_opts)
    warden.set_user(resource, scope: scope)
  end

  def sign_out(scope = :user)
    warden.logout(scope)
  end

  private

  def warden
    request.env.fetch("warden")
  end

  def force_json_format
    request.format = :json
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: { message: e.message } }, status: :bad_request
  end

  rescue_from Pundit::NotAuthorizedError do |e|
    render json: { error: { message: e.message.presence || "Forbidden" } }, status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { message: "Not found" } }, status: :not_found
  end
end
