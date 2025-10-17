# frozen_string_literal: true

# Simple Rack app used by Warden as failure app to avoid any session usage
class ApiFailureApp
  def self.call(env)
    [401, { 'Content-Type' => 'application/json' }, [{ error: 'Authentication failed' }.to_json]]
  end
end
