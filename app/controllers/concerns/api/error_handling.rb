# frozen_string_literal: true

module Api
  module ErrorHandling
    extend ActiveSupport::Concern

    # Error code mapping for consistent API responses
    ERROR_CODES = {
      bad_request: "bad_request",
      unauthorized: "unauthorized",
      forbidden: "forbidden",
      not_found: "not_found",
      conflict: "conflict",
      unprocessable_entity: "validation_error",
      internal_server_error: "internal_error"
    }.freeze

    included do
      # === Catch-all for unexpected errors (must be first - lowest priority) ===
      rescue_from StandardError do |e|
        handle_unexpected_error(e)
      end

      # === Users ===
      rescue_from Users::PasswordChangeService::Forbidden do |e|
        render_error(e.message, status: :forbidden, code: "password_change_forbidden")
      end

      rescue_from Users::ProfileUpdateService::ValidationError,
                  Users::PasswordChangeService::ValidationError,
                  Users::AccountDeleteService::ValidationError do |e|
        render_validation_error(e.details, message: e.message)
      end

      # === Standard Rails/Gems ===
      rescue_from ActiveRecord::RecordNotFound do |e|
        render_error("Not found", status: :not_found, code: "record_not_found")
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_error(e.record.errors.to_hash)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request, code: "parameter_missing")
      end

      rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
        render_error("Invalid JSON in request body", status: :bad_request, code: "parse_error")
      end

      rescue_from Pundit::NotAuthorizedError do |e|
        render_error("Forbidden", status: :forbidden, code: "not_authorized")
      end

      # === Auth ===
      rescue_from ::Auth::Login::BadRequest,
                  ::Auth::Register::BadRequest do |e|
        render_error(e.message, status: :bad_request, code: "auth_bad_request")
      end

      rescue_from ::Auth::Login::Unauthorized do |e|
        response.set_header("WWW-Authenticate", 'Bearer realm="Application"')
        render_error(e.message, status: :unauthorized, code: "auth_unauthorized")
      end

      rescue_from ::Auth::TokenService::TokenInvalid do |e|
        render_error(e.message, status: :unauthorized, code: "token_invalid")
      end

      rescue_from ::Auth::TokenService::TokenExpired do |e|
        render_error(e.message, status: :unauthorized, code: "token_expired")
      end

      rescue_from ::Auth::TokenService::TokenRevoked do |e|
        render_error(e.message, status: :unauthorized, code: "token_revoked")
      end

      rescue_from ::Auth::TokenService::TokenReused do |e|
        render_error(e.message, status: :unauthorized, code: "token_reused")
      end

      # === Devices ===
      rescue_from Devices::Upsert::BadRequest do |e|
        render_error(e.message, status: :bad_request, code: "device_bad_request")
      end

      # === Memberships ===
      rescue_from Memberships::Create::BadRequest,
                  Memberships::Update::BadRequest do |e|
        render_error(e.message, status: :bad_request, code: "membership_bad_request")
      end

      rescue_from Memberships::Create::NotFound do |e|
        render_error(e.message, status: :not_found, code: "membership_not_found")
      end

      rescue_from Memberships::Create::Conflict,
                  Memberships::Destroy::Conflict do |e|
        render_error(e.message, status: :conflict, code: "membership_conflict")
      end

      rescue_from Memberships::Create::Forbidden do |e|
        render_error(e.message, status: :forbidden, code: "membership_forbidden")
      end

      # === Task Services ===
      rescue_from TaskAssignmentService::BadRequest do |e|
        render_error(e.message, status: :bad_request, code: "task_assignment_bad_request")
      end

      rescue_from TaskAssignmentService::InvalidAssignee do |e|
        render_error(e.message, status: :unprocessable_entity, code: "task_assignment_invalid")
      end

      rescue_from TaskNudgeService::SelfNudge do |e|
        render_error(e.message, status: :unprocessable_entity, code: "nudge_self_not_allowed")
      end

      rescue_from TaskCompletionService::MissingReasonError do |e|
        render_error(e.message, status: :unprocessable_entity, code: "completion_reason_required")
      end

      rescue_from TaskUpdateService::ValidationError do |e|
        render_validation_error(e.respond_to?(:details) ? e.details : {}, message: e.message)
      end

      # === List Services ===
      rescue_from ListCreationService::ValidationError,
                  ListUpdateService::ValidationError do |e|
        render_validation_error(e.respond_to?(:details) ? e.details : {}, message: e.message)
      end

      rescue_from ListUpdateService::UnauthorizedError,
                  TaskUpdateService::UnauthorizedError,
                  TaskCompletionService::UnauthorizedError do |e|
        render_error(e.message, status: :forbidden, code: "update_forbidden")
      end
    end

    private

    def render_error(message, status:, code: nil)
      code ||= ERROR_CODES[status] || status.to_s
      render json: {
        error: {
          code: code,
          message: message
        }
      }, status: status
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

    def handle_unexpected_error(exception)
      # Log the full error for debugging
      Rails.logger.error("[UnexpectedError] #{exception.class}: #{exception.message}")
      Rails.logger.error(exception.backtrace&.first(10)&.join("\n"))

      # Report to error tracking service
      context = {
        controller: controller_name,
        action: action_name
      }
      context[:user_id] = current_user.id if respond_to?(:current_user) && current_user

      Rails.error.report(exception, handled: true, context: context)

      # Return safe message to client
      message = Rails.env.local? ? "#{exception.class}: #{exception.message}" : "An unexpected error occurred"
      render_error(message, status: :internal_server_error, code: "internal_error")
    end
  end
end
