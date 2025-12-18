# frozen_string_literal: true

# Rack app used by Warden as a failure app for API-only authentication.
# Ensures we return JSON (not redirects) and never rely on session state.
class ApiFailureApp
  CONTENT_TYPE = "application/json"
  WWW_AUTHENTICATE = 'Bearer realm="Application"'

  def self.call(_env)
    body = {
      error: {
        code: "unauthorized",
        message: "Unauthorized"
      }
    }.to_json

    [
      401,
      {
        "Content-Type" => CONTENT_TYPE,
        "WWW-Authenticate" => WWW_AUTHENTICATE
      },
      [body]
    ]
  end
end
