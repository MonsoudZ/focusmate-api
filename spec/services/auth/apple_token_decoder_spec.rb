# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::AppleTokenDecoder do
  describe ".decode" do
    let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:kid) { "test-key-id" }

    let(:valid_claims) do
      {
        "sub" => "apple-user-123",
        "email" => "user@example.com",
        "iss" => "https://appleid.apple.com",
        "aud" => "com.intentia.app"
      }
    end

    let(:jwk) { JWT::JWK.new(rsa_key, kid: kid) }

    let(:id_token) do
      JWT.encode(valid_claims, rsa_key, "RS256", { kid: kid })
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APPLE_BUNDLE_ID").and_return("com.intentia.app")
      allow_any_instance_of(described_class).to receive(:fetch_apple_public_keys)
        .and_return([ jwk.export.transform_keys(&:to_s) ])
    end

    it "decodes a valid Apple ID token" do
      claims = described_class.decode(id_token)

      expect(claims["sub"]).to eq("apple-user-123")
      expect(claims["email"]).to eq("user@example.com")
    end

    it "returns nil for blank token" do
      expect(described_class.decode("")).to be_nil
      expect(described_class.decode(nil)).to be_nil
    end

    it "returns nil when key ID does not match" do
      wrong_key = OpenSSL::PKey::RSA.generate(2048)
      wrong_token = JWT.encode(valid_claims, wrong_key, "RS256", { kid: "wrong-kid" })

      expect(described_class.decode(wrong_token)).to be_nil
    end

    it "returns nil when Apple keys payload is malformed" do
      allow_any_instance_of(described_class).to receive(:fetch_apple_public_keys).and_return(nil)

      expect(described_class.decode(id_token)).to be_nil
    end

    it "returns nil for malformed tokens" do
      expect(described_class.decode("not.a.jwt")).to be_nil
      expect(described_class.decode("totally-invalid")).to be_nil
    end

    it "delegates from class method to instance" do
      claims = described_class.decode(id_token)

      expect(claims).to be_a(Hash)
      expect(claims["sub"]).to eq("apple-user-123")
    end

    it "returns nil when token header has no kid" do
      # Build a token with an empty kid header
      token_without_kid = JWT.encode(valid_claims, rsa_key, "RS256", { kid: "" })

      expect(described_class.decode(token_without_kid)).to be_nil
    end

    context "when Apple keys endpoint returns an HTTP error" do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_apple_public_keys).and_call_original
        error_response = instance_double(Net::HTTPServiceUnavailable, code: "503", body: "")
        allow(error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:start).and_return(error_response)
        Rails.cache.delete("apple_auth_public_keys")
      end

      it "returns nil" do
        expect(described_class.decode(id_token)).to be_nil
      end
    end

    context "when Apple keys payload is missing keys array" do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_apple_public_keys).and_call_original
        ok_response = instance_double(Net::HTTPOK, body: { "not_keys" => "something" }.to_json)
        allow(ok_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:start).and_return(ok_response)
        Rails.cache.delete("apple_auth_public_keys")
      end

      it "returns nil" do
        expect(described_class.decode(id_token)).to be_nil
      end
    end
  end
end
