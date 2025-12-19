# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health Endpoints', type: :request do
  describe 'GET /health/live' do
    it 'returns 200 OK' do
      get '/health/live'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq("ok" => true)
    end
  end

  describe 'GET /health/ready' do
    it 'returns service status' do
      allow(Health::Report).to receive(:ready).and_return({
        status: "healthy",
        checks: {
          database: { status: "healthy", message: "OK" },
          redis: { status: "healthy", message: "OK" },
          queue: { status: "healthy", message: "OK" }
        }
      })
      allow(Health::Report).to receive(:http_status).and_return(:ok)

      get '/health/ready'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      json = JSON.parse(response.body)
      expect(json).to have_key('status')
      expect(json).to have_key('checks')
      expect(json['status']).to eq('healthy')
    end

    it 'returns degraded status when services are down' do
      allow(Health::Report).to receive(:ready).and_return({
        status: "degraded",
        checks: {
          database: { status: "unhealthy", message: "Connection failed" },
          redis: { status: "healthy", message: "OK" },
          queue: { status: "healthy", message: "OK" }
        }
      })
      allow(Health::Report).to receive(:http_status).and_return(:service_unavailable)

      get '/health/ready'

      expect(response).to have_http_status(:service_unavailable)

      json = JSON.parse(response.body)
      expect(json['status']).to eq('degraded')
      expect(json['checks']['database']['status']).to eq('unhealthy')
    end
  end
end
