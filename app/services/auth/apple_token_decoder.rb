# frozen_string_literal: true

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

      header = JSON.parse(Base64.decode64(header_segment))
      kid = header["kid"]

      apple_keys = fetch_apple_public_keys
      key_data = apple_keys.find { |k| k["kid"] == kid }
      return nil unless key_data

      jwk = JWT::JWK.new(key_data)

      decoded = JWT.decode(
        id_token,
        jwk.public_key,
        true,
        {
          algorithm: "RS256",
          iss: APPLE_ISSUER,
          verify_iss: true,
          aud: ENV["APPLE_BUNDLE_ID"],
          verify_aud: true
        }
      )

      decoded.first
    rescue JSON::ParserError, ArgumentError
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
        JSON.parse(response.body)["keys"]
      end
    end
  end
end
