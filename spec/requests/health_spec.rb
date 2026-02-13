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

  describe "diagnostic auth in production" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("HEALTH_DIAGNOSTICS_TOKEN").and_return("health-secret")
    end

    it "requires X-Health-Token for detailed endpoint" do
      get "/health/detailed"

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires X-Health-Token for metrics endpoint" do
      get "/health/metrics"

      expect(response).to have_http_status(:unauthorized)
    end

    it "allows diagnostics when token is valid" do
      get "/health/metrics", headers: { "X-Health-Token" => "health-secret" }

      expect(response).to have_http_status(:ok)
      expect(json_response["health"]).to be_in([ 0, 1 ])
    end

    it "rejects invalid token" do
      get "/health/detailed", headers: { "X-Health-Token" => "wrong-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 when production token is not configured" do
      allow(ENV).to receive(:[]).with("HEALTH_DIAGNOSTICS_TOKEN").and_return(nil)

      get "/health/detailed", headers: { "X-Health-Token" => "anything" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
