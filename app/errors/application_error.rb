# frozen_string_literal: true

# Base error class for all application errors.
# Subclasses define their own HTTP status and error code.
#
# Usage:
#   raise ApplicationError::NotFound, "User not found"
#   raise ApplicationError::Forbidden.new("Cannot edit", code: "edit_forbidden")
#   raise ApplicationError::Validation.new("Invalid", details: { name: ["can't be blank"] })
#
class ApplicationError < StandardError
  attr_reader :code, :details

  def initialize(message = nil, code: nil, details: {})
    @code = code || default_code
    @details = details
    super(message || default_message)
  end

  def status
    :internal_server_error
  end

  def status_code
    Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
  end

  private

  def default_code
    "internal_error"
  end

  def default_message
    "An unexpected error occurred"
  end

  # === HTTP 400 Bad Request ===
  class BadRequest < ApplicationError
    def status = :bad_request
    def default_code = "bad_request"
    def default_message = "Bad request"
  end

  # === HTTP 401 Unauthorized ===
  class Unauthorized < ApplicationError
    def status = :unauthorized
    def default_code = "unauthorized"
    def default_message = "Unauthorized"
  end

  # === HTTP 403 Forbidden ===
  class Forbidden < ApplicationError
    def status = :forbidden
    def default_code = "forbidden"
    def default_message = "Forbidden"
  end

  # === HTTP 404 Not Found ===
  class NotFound < ApplicationError
    def status = :not_found
    def default_code = "not_found"
    def default_message = "Not found"
  end

  # === HTTP 409 Conflict ===
  class Conflict < ApplicationError
    def status = :conflict
    def default_code = "conflict"
    def default_message = "Conflict"
  end

  # === HTTP 422 Unprocessable Entity (with validation details) ===
  class Validation < ApplicationError
    def initialize(message = nil, details: {}, code: nil)
      super(message || "Validation failed", code: code || "validation_error", details: details)
    end

    def status = :unprocessable_entity
  end

  # === HTTP 422 Unprocessable Entity (generic) ===
  class UnprocessableEntity < ApplicationError
    def status = :unprocessable_entity
    def default_code = "unprocessable_entity"
    def default_message = "Unprocessable entity"
  end

  # === Token-specific errors (401) ===
  class TokenInvalid < Unauthorized
    def default_code = "token_invalid"
    def default_message = "Token is invalid"
  end

  class TokenExpired < Unauthorized
    def default_code = "token_expired"
    def default_message = "Token has expired"
  end

  class TokenRevoked < Unauthorized
    def default_code = "token_revoked"
    def default_message = "Token has been revoked"
  end

  class TokenReused < Unauthorized
    def default_code = "token_reused"
    def default_message = "Token has already been used"
  end

  class TokenAlreadyRefreshed < Unauthorized
    def default_code = "token_already_refreshed"
    def default_message = "Token was already refreshed"
  end
end
