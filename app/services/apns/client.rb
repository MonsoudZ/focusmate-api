# frozen_string_literal: true

require "net/http"
require "jwt"
require "json"
require "securerandom"
require "openssl"
require "monitor"

module Apns
  class Client
    include MonitorMixin

    DEFAULT_PUSH_TYPE = "alert" # "alert" | "background" | "voip" | "complication" | "fileprovider" | "mdm"
    DEFAULT_PRIORITY  = 10      # 10 (immediate) or 5 (background)
    TOKEN_TTL_SECONDS = 20 * 60 # refresh every 20 minutes (APNs allows up to 1h)

    def initialize(
      team_id:      ENV.fetch("APNS_TEAM_ID"),
      key_id:       ENV.fetch("APNS_KEY_ID"),
      bundle_id:    ENV.fetch("APNS_TOPIC"),
      p8:           ENV.fetch("APNS_CERT_PATH"),
      environment:  ENV.fetch("APNS_ENVIRONMENT", "development") # "production" or "sandbox"
    )
      super() # Monitor
      @team_id   = team_id
      @key_id    = key_id
      @bundle_id = bundle_id
      @p8_key    = load_ec_key!(p8)
      @env       = environment

      @jwt       = nil
      @jwt_iat   = 0
    end

    # Public API:
    # payload: a Ruby Hash that becomes your APNs JSON body, e.g. { aps: { alert: { title: "...", body: "..." }, sound: "default" } }
    #
    # Options:
    #  push_type:  "alert" (default) | "background" | ...
    #  topic:      override apns-topic (defaults to bundle_id; for VoIP, e.g. "#{bundle_id}.voip")
    #  apns_id:    a UUID you pass; APNs returns it back
    #  expiration: Unix epoch seconds when the notification expires (0 means immediately discard if not delivered)
    #  priority:   10 or 5
    #
    # Returns: { ok: true, apns_id:, status: 200 } on success
    #          { ok: false, status:, reason:, timestamp: } on error
    def send_notification(device_token, payload, push_type: DEFAULT_PUSH_TYPE, topic: nil, apns_id: nil, expiration: 0, priority: DEFAULT_PRIORITY)
      headers = {
        "authorization"  => "bearer #{jwt!}",
        "apns-topic"     => (topic || @bundle_id),
        "apns-push-type" => push_type,
        "apns-priority"  => priority.to_s,
        "content-type"   => "application/json"
      }
      headers["apns-id"]        = apns_id if apns_id
      headers["apns-expiration"]= expiration.to_s if expiration && expiration.to_i > 0

      path    = "/3/device/#{device_token}"
      body    = JSON.generate(payload)

      # Use standard Net::HTTP with HTTP/2 support
      uri = URI("https://#{apns_host}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Post.new(uri)
      headers.each { |k, v| request[k] = v }
      request.body = body

      response = http.request(request)
      status = response.code.to_i
      apns_id_hdr = response["apns-id"]

      if status == 200
        { ok: true, apns_id: apns_id_hdr, status: status }
      else
        err = parse_error(response.body)
        { ok: false, status: status, reason: err["reason"], timestamp: err["timestamp"], apns_id: apns_id_hdr }
      end
    rescue => e
      # Connection errors, etc.
      { ok: false, status: 0, reason: "HTTP error: #{e.class}: #{e.message}" }
    end

    def close
      # No persistent connection to close
    end

    private

    def apns_host
      @env.to_s == "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com"
    end

    def load_ec_key!(p8)
      key = if File.file?(p8)
        OpenSSL::PKey.read(File.read(p8))
      else
        OpenSSL::PKey.read(p8)
      end
      unless key.is_a?(OpenSSL::PKey::EC) && key.private?
        raise ArgumentError, "APNS_CERT_PATH must be an EC private key (.p8) with a private component"
      end
      key
    end

    def jwt!
      now = Time.now.to_i
      synchronize do
        if @jwt.nil? || (now - @jwt_iat) >= TOKEN_TTL_SECONDS
          headers = { kid: @key_id, alg: "ES256", typ: "JWT" }
          claims  = { iss: @team_id, iat: now } # APNs only wants iss + iat
          @jwt    = JWT.encode(claims, @p8_key, "ES256", headers)
          @jwt_iat = now
        end
        @jwt
      end
    end

    def parse_error(body)
      JSON.parse(body)
    rescue JSON::ParserError
      { "reason" => "UnparseableResponse", "raw" => body.to_s }
    end
  end
end
