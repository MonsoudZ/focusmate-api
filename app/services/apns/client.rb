# frozen_string_literal: true

require "net/http"
require "jwt"
require "json"
require "securerandom"
require "openssl"
require "monitor"
require "base64"

module Apns
  class Client
    include MonitorMixin

    DEFAULT_PUSH_TYPE = "alert"
    DEFAULT_PRIORITY  = 10
    TOKEN_TTL_SECONDS = 20 * 60

    def self.enabled?
      ENV["APNS_TEAM_ID"].present? &&
        ENV["APNS_KEY_ID"].present? &&
        ENV["APNS_TOPIC"].present? &&
        ENV["APNS_AUTH_KEY_B64"].present?
    end

    def initialize(
      team_id:     ENV["APNS_TEAM_ID"],
      key_id:      ENV["APNS_KEY_ID"],
      bundle_id:   ENV["APNS_TOPIC"],
      auth_key_b64: ENV["APNS_AUTH_KEY_B64"],
      environment: ENV.fetch("APNS_ENVIRONMENT", "sandbox") # "sandbox" or "production"
    )
      super() # Monitor

      @enabled = team_id.present? && key_id.present? && bundle_id.present? && auth_key_b64.present?
      return unless @enabled

      @team_id   = team_id
      @key_id    = key_id
      @bundle_id = bundle_id
      @env       = environment

      # Decode the .p8 contents from Base64 (Railway env var)
      raw_key = Base64.decode64(auth_key_b64)
      @p8_key  = load_ec_key_from_string!(raw_key)

      @jwt     = nil
      @jwt_iat = 0
    end

    def enabled?
      @enabled
    end

    def send_notification(device_token, payload, push_type: DEFAULT_PUSH_TYPE, topic: nil, apns_id: nil, expiration: 0, priority: DEFAULT_PRIORITY)
      return { ok: false, status: 0, reason: "APNs disabled (missing env vars)" } unless enabled?

      headers = {
        "authorization"  => "bearer #{jwt!}",
        "apns-topic"     => (topic || @bundle_id),
        "apns-push-type" => push_type,
        "apns-priority"  => priority.to_s,
        "content-type"   => "application/json"
      }
      headers["apns-id"]         = apns_id if apns_id
      headers["apns-expiration"] = expiration.to_s if expiration && expiration.to_i > 0

      path = "3/device/#{device_token}" # NOTE: no leading slash when interpolating into URL below
      body = JSON.generate(payload)

      uri  = URI("https://#{apns_host}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Post.new(uri)
      headers.each { |k, v| request[k] = v }
      request.body = body

      response = http.request(request)
      status   = response.code.to_i
      apns_id_hdr = response["apns-id"]

      if status == 200
        { ok: true, apns_id: apns_id_hdr, status: status }
      else
        err = parse_error(response.body)
        { ok: false, status: status, reason: err["reason"], timestamp: err["timestamp"], apns_id: apns_id_hdr }
      end
    rescue => e
      { ok: false, status: 0, reason: "HTTP error: #{e.class}: #{e.message}" }
    end

    def close
      # no-op (no persistent connection)
    end

    private

    def apns_host
      @env.to_s == "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com"
    end

    def load_ec_key_from_string!(p8_contents)
      key = OpenSSL::PKey.read(p8_contents)
      unless key.is_a?(OpenSSL::PKey::EC) && key.private?
        raise ArgumentError, "APNS_AUTH_KEY_B64 must decode to an EC private key (.p8) with a private component"
      end
      key
    end

    def jwt!
      now = Time.now.to_i
      synchronize do
        if @jwt.nil? || (now - @jwt_iat) >= TOKEN_TTL_SECONDS
          headers = { kid: @key_id, alg: "ES256", typ: "JWT" }
          claims  = { iss: @team_id, iat: now }
          @jwt     = JWT.encode(claims, @p8_key, "ES256", headers)
          @jwt_iat  = now
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
