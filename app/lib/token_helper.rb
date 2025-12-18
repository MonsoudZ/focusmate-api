# frozen_string_literal: true

module TokenHelper
  module_function

  # Redact device tokens for logging.
  #
  # - development/test: show full token (useful for debugging)
  # - other envs: show a small fingerprint only (safe for logs)
  def redact_token(token)
    return "(nil)" if token.blank?

    t = token.to_s

    return t if Rails.env.development? || Rails.env.test?

    # Show enough to correlate while avoiding leakage
    head = t.first(6)
    tail = t.last(6)
    "#{head}…#{tail}"
  end
end
