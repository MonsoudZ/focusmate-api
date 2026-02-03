# frozen_string_literal: true

module Api
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      # === Catch-all for unexpected errors (must be first - lowest priority) ===
      rescue_from StandardError do |e|
        handle_unexpected_error(e)
      end

      # === Application errors (single handler for all custom errors) ===
      rescue_from ApplicationError do |e|
        render_application_error(e)
      end

      # === Standard Rails/Gems errors ===
      rescue_from ActiveRecord::RecordNotFound do |e|
        render_error("Not found", status: :not_found, code: "not_found")
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
    end

    private

    def render_application_error(error)
      if error.is_a?(ApplicationError::Validation) && error.details.present?
        render_validation_error(error.details, message: error.message)
      else
        render_error(error.message, status: error.status, code: error.code)
      end
    end

    def render_error(message, status:, code: nil)
      render json: {
        error: {
          code: code || status.to_s,
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
      }, status: :unprocessable_content
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
