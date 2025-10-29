# frozen_string_literal: true

module ErrorResponseHelper
  extend ActiveSupport::Concern

  # Standard error response format
  def render_error(message, status = :bad_request, details = nil)
    error_response = {
      error: {
        message: message,
        status: Rack::Utils.status_code(status),
        timestamp: Time.current.iso8601
      }
    }

    error_response[:error][:details] = details if details.present?

    render json: error_response, status: status
  end

  # Validation error response with improved error handling
  def render_validation_errors(errors, status = :unprocessable_entity)
    error_details = if errors.is_a?(ActiveModel::Errors)
                      errors.as_json
    elsif errors.respond_to?(:to_hash)
                      errors.to_hash
    else
                      errors
    end

    render json: {
      error: {
        message: "Validation failed",
        details: error_details
      }
    }, status: status
  end

  # Not found error response
  def render_not_found(resource = "Resource")
    render json: { error: { message: "#{resource} not found" } }, status: :not_found
  end

  # Unauthorized error response
  def render_unauthorized(message = "Unauthorized")
    render json: {
      error: {
        message: message,
        status: 401,
        timestamp: Time.current.iso8601
      }
    }, status: :unauthorized
  end

  # Forbidden error response
  def render_forbidden(message = "Forbidden")
    render_error(message, :forbidden)
  end

  # Rate limit error response with enhanced details
  def render_rate_limit_exceeded(limit = nil, reset_time = nil)
    error_response = {
      error: {
        message: "Rate limit exceeded",
        status: 429,
        timestamp: Time.current.iso8601
      }
    }

    if limit.present? && reset_time.present?
      error_response[:error][:details] = {
        limit: limit,
        reset_at: Time.at(reset_time).iso8601,
        retry_after: [ (reset_time - Time.current.to_i).to_i, 0 ].max
      }
    end

    render json: error_response, status: :too_many_requests
  end

  # Server error response
  def render_server_error(message = "Internal server error")
    render_error(message, :internal_server_error)
  end

  # Bad request error response
  def render_bad_request(message = "Bad request")
    render_error(message, :bad_request)
  end

  # Conflict error response
  def render_conflict(message = "Conflict")
    render_error(message, :conflict)
  end

  # Method not allowed error response
  def render_method_not_allowed(message = "Method not allowed")
    render_error(message, :method_not_allowed)
  end

  # Unprocessable entity error response
  def render_unprocessable_entity(message = "Unprocessable entity")
    render_error(message, :unprocessable_entity)
  end

  # Service unavailable error response
  def render_service_unavailable(message = "Service temporarily unavailable")
    render_error(message, :service_unavailable)
  end

  # Gateway timeout error response
  def render_gateway_timeout(message = "Gateway timeout")
    render_error(message, :gateway_timeout)
  end

  # Not implemented error response
  def render_not_implemented(message = "Not implemented")
    render_error(message, :not_implemented)
  end

  # Too many requests error response (alias for rate limit)
  def render_too_many_requests(message = "Too many requests")
    render_error(message, :too_many_requests)
  end

  # Payment required error response
  def render_payment_required(message = "Payment required")
    render_error(message, :payment_required)
  end

  # Length required error response
  def render_length_required(message = "Length required")
    render_error(message, :length_required)
  end

  # Precondition failed error response
  def render_precondition_failed(message = "Precondition failed")
    render_error(message, :precondition_failed)
  end

  # Request entity too large error response
  def render_payload_too_large(message = "Request entity too large")
    render_error(message, :payload_too_large)
  end

  # Request URI too long error response
  def render_uri_too_long(message = "Request URI too long")
    render_error(message, :uri_too_long)
  end

  # Unsupported media type error response
  def render_unsupported_media_type(message = "Unsupported media type")
    render_error(message, :unsupported_media_type)
  end

  # Requested range not satisfiable error response
  def render_range_not_satisfiable(message = "Requested range not satisfiable")
    render_error(message, :range_not_satisfiable)
  end

  # Expectation failed error response
  def render_expectation_failed(message = "Expectation failed")
    render_error(message, :expectation_failed)
  end

  # Locked error response
  def render_locked(message = "Resource is locked")
    render_error(message, :locked)
  end

  # Failed dependency error response
  def render_failed_dependency(message = "Failed dependency")
    render_error(message, :failed_dependency)
  end

  # Too early error response
  def render_too_early(message = "Too early")
    render_error(message, :too_early)
  end

  # Upgrade required error response
  def render_upgrade_required(message = "Upgrade required")
    render_error(message, :upgrade_required)
  end

  # Precondition required error response
  def render_precondition_required(message = "Precondition required")
    render_error(message, :precondition_required)
  end

  # Request header fields too large error response
  def render_request_header_fields_too_large(message = "Request header fields too large")
    render_error(message, :request_header_fields_too_large)
  end

  # Unavailable for legal reasons error response
  def render_unavailable_for_legal_reasons(message = "Unavailable for legal reasons")
    render_error(message, :unavailable_for_legal_reasons)
  end

  # Bad gateway error response
  def render_bad_gateway(message = "Bad gateway")
    render_error(message, :bad_gateway)
  end

  # HTTP version not supported error response
  def render_http_version_not_supported(message = "HTTP version not supported")
    render_error(message, :http_version_not_supported)
  end

  # Variant also negotiates error response
  def render_variant_also_negotiates(message = "Variant also negotiates")
    render_error(message, :variant_also_negotiates)
  end

  # Insufficient storage error response
  def render_insufficient_storage(message = "Insufficient storage")
    render_error(message, :insufficient_storage)
  end

  # Loop detected error response
  def render_loop_detected(message = "Loop detected")
    render_error(message, :loop_detected)
  end

  # Not extended error response
  def render_not_extended(message = "Not extended")
    render_error(message, :not_extended)
  end

  # Network authentication required error response
  def render_network_authentication_required(message = "Network authentication required")
    render_error(message, :network_authentication_required)
  end

  # Unprocessable content error response (alias for unprocessable_entity)
  def render_unprocessable_content(message = "Unprocessable content")
    render_unprocessable_entity(message)
  end

  # Internal server error response (alias for server_error)
  def render_internal_server_error(message = "Internal server error")
    render_server_error(message)
  end

  private

  # Helper method to ensure consistent error response structure
  def build_error_response(message, status, details = nil)
    response = {
      error: {
        message: message,
        status: Rack::Utils.status_code(status),
        timestamp: Time.current.iso8601
      }
    }

    response[:error][:details] = details if details.present?
    response
  end

  # Helper method to validate error details
  def validate_error_details(details)
    return nil if details.nil?

    case details
    when Hash, Array, String, Numeric, TrueClass, FalseClass, NilClass
      details
    when ActiveModel::Errors
      details.as_json
    else
      details.to_s
    end
  end
end
