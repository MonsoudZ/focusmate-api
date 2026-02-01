# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS", type: :request do
  describe "preflight requests" do
    it "responds to OPTIONS requests from allowed origins" do
      options "/api/v1/lists",
        headers: {
          "Origin" => "http://localhost:3000",
          "Access-Control-Request-Method" => "GET",
          "Access-Control-Request-Headers" => "Authorization"
        }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:3000")
      expect(response.headers["Access-Control-Allow-Methods"]).to include("GET")
      expect(response.headers["Access-Control-Allow-Headers"]).to be_present
    end

    it "includes max-age for preflight caching" do
      options "/api/v1/lists",
        headers: {
          "Origin" => "http://localhost:3000",
          "Access-Control-Request-Method" => "GET"
        }

      expect(response.headers["Access-Control-Max-Age"]).to eq("86400")
    end
  end

  describe "actual requests" do
    let(:user) { create(:user) }
    let(:headers) do
      token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      {
        "Authorization" => "Bearer #{token}",
        "Origin" => "http://localhost:3000"
      }
    end

    it "includes CORS headers in responses from allowed origins" do
      get "/api/v1/lists", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:3000")
      expect(response.headers["Access-Control-Expose-Headers"]).to include("Authorization")
    end

    it "does not include CORS headers for requests without Origin" do
      get "/api/v1/lists", headers: headers.except("Origin")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "disallowed origins" do
    it "does not include CORS headers for unknown origins in test env" do
      # In test environment, only localhost origins are allowed
      options "/api/v1/lists",
        headers: {
          "Origin" => "https://malicious-site.com",
          "Access-Control-Request-Method" => "GET"
        }

      # rack-cors returns 200 but without the Allow-Origin header for disallowed origins
      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end
end
