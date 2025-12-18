# frozen_string_literal: true

module Api
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from Auth::Login::BadRequest, Auth::Register::BadRequest do |e|
        render json: { error: { message: e.message } }, status: :bad_request
      end

      rescue_from Auth::Login::Unauthorized do |e|
        response.set_header("WWW-Authenticate", 'Bearer realm="Application"')
        render json: { error: { message: e.message } }, status: :unauthorized
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: {
          code: "validation_error",
          message: "Validation failed",
          details: e.record.errors.to_hash
        }, status: :unprocessable_content
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: { message: e.message } }, status: :bad_request
      end
      rescue_from ActiveRecord::RecordNotFound do
        render_error("Not found", status: :not_found)
      end

      rescue_from Pundit::NotAuthorizedError do
        render_error("Forbidden", status: :forbidden)
      end

      rescue_from Memberships::Create::BadRequest, Memberships::Update::BadRequest do |e|
        render_error(e.message, status: :bad_request)
      end

      rescue_from Memberships::Create::NotFound do |e|
        render_error(e.message, status: :not_found)
      end

      rescue_from Memberships::Create::Conflict do |e|
        render_error(e.message, status: :unprocessable_content)
      end

      rescue_from Memberships::Destroy::Conflict do |e|
        render json: { error: { message: e.message } }, status: :unprocessable_content
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request)
      end
    end

    private

    def render_error(message, status:)
      render json: { error: { message: message } }, status: status
    end
  end
end
