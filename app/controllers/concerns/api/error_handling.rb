# frozen_string_literal: true

module Api
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      # === Users ===
      rescue_from Users::PasswordChangeService::Forbidden do |e|
        render_error(e.message, status: :forbidden)
      end

      rescue_from Users::ProfileUpdateService::ValidationError,
                  Users::PasswordChangeService::ValidationError,
                  Users::AccountDeleteService::ValidationError do |e|
        render_validation_error(e.details, message: e.message)
      end
      # === Standard Rails/Gems ===
      rescue_from ActiveRecord::RecordNotFound do
        render_error("Not found", status: :not_found)
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_error(e.record.errors.to_hash)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request)
      end

      rescue_from Pundit::NotAuthorizedError do
        render_error("Forbidden", status: :forbidden)
      end

      # === Auth ===
      rescue_from ::Auth::Login::BadRequest,
                  ::Auth::Register::BadRequest do |e|
        render_error(e.message, status: :bad_request)
      end

      rescue_from ::Auth::Login::Unauthorized do |e|
        response.set_header("WWW-Authenticate", 'Bearer realm="Application"')
        render_error(e.message, status: :unauthorized)
      end

      rescue_from ::Auth::TokenService::TokenInvalid,
                  ::Auth::TokenService::TokenExpired,
                  ::Auth::TokenService::TokenRevoked,
                  ::Auth::TokenService::TokenReused do |e|
        render_error(e.message, status: :unauthorized)
      end

      # === Devices ===
      rescue_from Devices::Upsert::BadRequest do |e|
        render_error(e.message, status: :bad_request)
      end

      # === Memberships ===
      rescue_from Memberships::Create::BadRequest,
                  Memberships::Update::BadRequest do |e|
        render_error(e.message, status: :bad_request)
      end

      rescue_from Memberships::Create::NotFound do |e|
        render_error(e.message, status: :not_found)
      end

      rescue_from Memberships::Create::Conflict,
                  Memberships::Destroy::Conflict do |e|
        render_error(e.message, status: :conflict)
      end

      rescue_from Memberships::Create::Forbidden do |e|
        render_error(e.message, status: :forbidden)
      end

      # === Services ===
      rescue_from ListCreationService::ValidationError,
                  ListUpdateService::ValidationError,
                  TaskUpdateService::ValidationError do |e|
        render_validation_error(e.respond_to?(:details) ? e.details : {}, message: e.message)
      end

      rescue_from ListUpdateService::UnauthorizedError,
                  TaskUpdateService::UnauthorizedError,
                  TaskCompletionService::UnauthorizedError do |e|
        render_error(e.message, status: :forbidden)
      end
    end

    private

    def render_error(message, status:)
      render json: { error: { message: message } }, status: status
    end

    def render_validation_error(details, message: "Validation failed")
      render json: {
        error: {
          code: "validation_error",
          message: message,
          details: details
        }
      }, status: :unprocessable_entity
    end
  end
end
