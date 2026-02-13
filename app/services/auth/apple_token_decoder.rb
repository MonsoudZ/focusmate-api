# frozen_string_literal: true

require "base64"
require "net/http"

module Auth
  class AppleTokenDecoder
    class InvalidToken < StandardError; end

    APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
    APPLE_ISSUER = "https://appleid.apple.com"

    def self.decode(id_token)
      new.decode(id_token)
    end

    def decode(id_token)
      header_segment = id_token.to_s.split(".").first
      return nil if header_segment.blank?

      header = decode_header_segment(header_segment)
      kid = header["kid"].to_s
      return nil if kid.blank?

      apple_keys = fetch_apple_public_keys
      return nil unless apple_keys.is_a?(Array)

      key_data = apple_keys.find { |k| k["kid"] == kid }

      if key_data.nil?
        Rails.logger.warn("[AppleAuth] No matching key found for kid")
        return nil
      end

      jwk = JWT::JWK.new(key_data)

      decoded = JWT.decode(
        id_token,
        jwk.public_key,
        true,
        {
          algorithm: "RS256",
          iss: APPLE_ISSUER,
          verify_iss: true,
          aud: Rails.application.credentials.dig(:apple, :bundle_id) || ENV["APPLE_BUNDLE_ID"],
          verify_aud: true
        }
      )

      decoded.first
    rescue JSON::ParserError, ArgumentError, InvalidToken => e
      Rails.logger.error("[AppleAuth] Parse error: #{e.message}")
      nil
    rescue JWT::DecodeError => e
      Rails.logger.error("[AppleAuth] JWT decode error: #{e.message}")
      nil
    end

    private

    def fetch_apple_public_keys
      Rails.cache.fetch("apple_auth_public_keys", expires_in: 5.minutes) do
        uri = URI(APPLE_KEYS_URL)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                   open_timeout: 5, read_timeout: 5) do |http|
          http.get(uri.path)
        end

        raise InvalidToken, "Apple keys endpoint returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        payload = JSON.parse(response.body)
        keys = payload["keys"]
        raise InvalidToken, "Apple keys payload missing keys" unless keys.is_a?(Array)

        keys
      end
    end

    def decode_header_segment(segment)
      normalized = segment.to_s
      padding_needed = (4 - (normalized.length % 4)) % 4
      normalized += "=" * padding_needed

      JSON.parse(Base64.urlsafe_decode64(normalized))
    end
  end
end
