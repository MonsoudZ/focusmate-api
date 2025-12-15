# frozen_string_literal: true

module TokenHelper
  module_function

  # Redact device tokens for logging
  # In dev: show full token
  # In prod: show only last 6 chars
  def redact_token(token)
    return "(nil)" if token.blank?

    if Rails.env.development?
      token.to_s
    else
      "…#{token.to_s.last(6)}"
    end
  end
end

