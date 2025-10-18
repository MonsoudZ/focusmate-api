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

  # Validation error response
  def render_validation_errors(errors, status = :unprocessable_entity)
    error_response = {
      error: {
        message: "Validation failed",
        status: Rack::Utils.status_code(status),
        timestamp: Time.current.iso8601,
        details: {
          validation_errors: errors.is_a?(ActiveModel::Errors) ? errors.full_messages : errors
        }
      }
    }

    render json: error_response, status: status
  end

  # Not found error response
  def render_not_found(resource = "Resource")
    render_error("#{resource} not found", :not_found)
  end

  # Unauthorized error response
  def render_unauthorized(message = "Unauthorized")
    render_error(message, :unauthorized)
  end

  # Forbidden error response
  def render_forbidden(message = "Forbidden")
    render_error(message, :forbidden)
  end

  # Rate limit error response
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
        reset_at: Time.at(reset_time).iso8601
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
end
