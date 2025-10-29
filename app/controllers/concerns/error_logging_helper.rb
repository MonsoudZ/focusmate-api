# frozen_string_literal: true

module ErrorLoggingHelper
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
    rescue_from ActionController::BadRequest, with: :handle_bad_request
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

  def handle_parameter_missing(exception)
    log_error(exception, severity: :warn)
    render_bad_request("Missing required parameter: #{exception.param}")
  end

  def handle_unpermitted_parameters(exception)
    log_error(exception, severity: :warn)
    render_bad_request("Unpermitted parameters: #{exception.params.join(', ')}")
  end

  def handle_bad_request(exception)
    log_error(exception, severity: :warn)
    render_bad_request("Bad request")
  end

  def log_error(exception, severity: :error)
    error_data = build_error_data(exception, severity)
    
    case severity
    when :error
      Rails.logger.error "API Error: #{error_data.to_json}"
    when :warn
      Rails.logger.warn "API Warning: #{error_data.to_json}"
    when :info
      Rails.logger.info "API Info: #{error_data.to_json}"
    end

    # Send to external error tracking service in production
    send_to_error_tracking(exception, error_data) if should_track_error?(severity)
  end

  def build_error_data(exception, severity)
    {
      exception: exception.class.name,
      message: exception.message,
      backtrace: backtrace_for_logging(exception),
      user_id: current_user&.id,
      request_id: request.request_id,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      method: request.method,
      path: request.path,
      params: sanitized_params,
      timestamp: Time.current.iso8601,
      severity: severity.to_s,
      environment: Rails.env
    }
  end

  def backtrace_for_logging(exception)
    return nil unless exception.backtrace
    
    if Rails.env.development? || Rails.env.test?
      exception.backtrace.first(10) # Limit in development
    else
      exception.backtrace.first(5) # Even more limited in production
    end
  end

  def sanitized_params
    # Remove sensitive parameters from logging
    sensitive_keys = %w[
      password password_confirmation token authorization
      device_token fcm_token apns_token push_token
      secret_key api_key access_token refresh_token
      credit_card cvv ssn social_security_number
    ]
    
    # Deep sanitize nested parameters
    sanitize_nested_params(params.except(*sensitive_keys).to_unsafe_h)
  end

  def sanitize_nested_params(params_hash)
    return params_hash unless params_hash.is_a?(Hash)
    
    params_hash.transform_values do |value|
      case value
      when Hash
        sanitize_nested_params(value)
      when Array
        value.map { |item| item.is_a?(Hash) ? sanitize_nested_params(item) : item }
      when String
        # Truncate very long strings
        value.length > 1000 ? "#{value[0...1000]}...[TRUNCATED]" : value
      else
        value
      end
    end
  end

  def should_track_error?(severity)
    # Only track errors and warnings in production
    return false unless Rails.env.production?
    %i[error warn].include?(severity)
  end

  def send_to_error_tracking(exception, error_data)
    # Integration with external error tracking services
    if defined?(Sentry)
      Sentry.with_scope do |scope|
        scope.set_user(id: current_user&.id, email: current_user&.email)
        scope.set_context("request", {
          method: request.method,
          path: request.path,
          params: error_data[:params]
        })
        Sentry.capture_exception(exception)
      end
    end

    # Add other error tracking services as needed
    # if defined?(Bugsnag)
    #   Bugsnag.notify(exception) do |report|
    #     report.add_tab(:user, { id: current_user&.id })
    #     report.add_tab(:request, error_data.slice(:method, :path, :params))
    #   end
    # end
  end
end