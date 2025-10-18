# config/initializers/apns.rb
require_relative "../../app/services/apns/client"

# Only initialize APNs connection if the certificate file exists
if ENV["APNS_CERT_PATH"].present? && File.exist?(ENV["APNS_CERT_PATH"])
  begin
    # Create custom APNs client with EC key support
    APNS_CLIENT = Apns::Client.new(
      team_id: ENV["APNS_TEAM_ID"],
      key_id: ENV["APNS_KEY_ID"],
      bundle_id: ENV["APNS_TOPIC"],
      p8: ENV["APNS_CERT_PATH"],
      environment: ENV["APNS_ENVIRONMENT"] || "development"
    )

    Rails.logger.info "[APNs] Custom client initialized successfully"
  rescue => e
    Rails.logger.error "[APNs] Failed to initialize custom client: #{e.message}"
    APNS_CLIENT = nil
  end
else
  Rails.logger.warn "[APNs] Certificate file not found at #{ENV['APNS_CERT_PATH']}. APNs notifications will be disabled."
  APNS_CLIENT = nil
end
