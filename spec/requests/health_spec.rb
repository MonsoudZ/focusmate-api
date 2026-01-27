# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health API", type: :request do
  describe "GET /health/live" do
    it "returns ok" do
      get "/health/live"

      expect(response).to have_http_status(:ok)
      expect(json_response["ok"]).to be true
    end

    it "does not require authentication" do
      get "/health/live"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /health/ready" do
    it "returns health status" do
      get "/health/ready"

      # May return 200 or 503 depending on service health
      expect([ 200, 503 ]).to include(response.status)
      expect(json_response["status"]).to be_present
      expect(json_response["checks"]).to be_an(Array)
    end

    it "includes timestamp" do
      get "/health/ready"

      expect(json_response["timestamp"]).to be_present
    end
  end

  describe "GET /health/detailed" do
    it "returns detailed health info" do
      get "/health/detailed"

      expect([ 200, 503 ]).to include(response.status)
      expect(json_response["status"]).to be_present
      expect(json_response["checks"]).to be_an(Array)
      expect(json_response["environment"]).to be_present
    end

    it "includes version info" do
      get "/health/detailed"

      expect(json_response["version"]).to be_present
    end
  end

  describe "GET /health/metrics" do
    it "returns numeric metrics" do
      get "/health/metrics"

      expect(response).to have_http_status(:ok)
      expect(json_response["health"]).to be_in([ 0, 1 ])
      expect(json_response["timestamp"]).to be_present
    end
  end
end
