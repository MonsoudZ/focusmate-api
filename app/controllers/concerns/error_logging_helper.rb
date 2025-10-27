# frozen_string_literal: true

module ErrorLoggingHelper
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error
  end

  private

  def handle_unexpected_error(exception)
    log_error(exception, severity: :error)
    render_server_error("An unexpected error occurred")
  end

  def handle_record_not_found(exception)
    log_error(exception, severity: :warn)
    render_not_found("Resource")
  end

  def handle_record_invalid(exception)
    log_error(exception, severity: :info)
    render_validation_errors(exception.record.errors)
  end

  def handle_authorization_error(exception)
    log_error(exception, severity: :warn)
    render_forbidden("You do not have permission to perform this action")
  end

  def log_error(exception, severity: :error)
    error_data = {
      exception: exception.class.name,
      message: exception.message,
      backtrace: Rails.env.development? ? exception.backtrace : nil,
      user_id: current_user&.id,
      request_id: request.request_id,
      params: sanitized_params,
      timestamp: Time.current.iso8601
    }

    case severity
    when :error
      Rails.logger.error "API Error: #{error_data.to_json}"
    when :warn
      Rails.logger.warn "API Warning: #{error_data.to_json}"
    when :info
      Rails.logger.info "API Info: #{error_data.to_json}"
    end

    # In production, you might want to send to external error tracking service
    # Sentry.capture_exception(exception) if defined?(Sentry)
  end

  def sanitized_params
    # Remove sensitive parameters from logging
    sensitive_keys = %w[password password_confirmation token authorization]
    params.except(*sensitive_keys).to_unsafe_h
  end
end
