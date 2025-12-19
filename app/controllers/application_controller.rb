# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :force_json_format
  before_action :authenticate_user!

  private

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
