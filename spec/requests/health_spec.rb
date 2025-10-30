# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health Endpoints', type: :request do
  describe 'GET /health/live' do
    it 'returns 200 OK' do
      get '/health/live'

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_empty
    end
  end

  describe 'GET /health/ready' do
    it 'returns service status' do
      # Mock all services as healthy
      allow_any_instance_of(HealthController).to receive(:database_health_check).and_return({
        status: "healthy",
        response_time_ms: 1.0,
        message: "Database connection active and responsive"
      })
      allow_any_instance_of(HealthController).to receive(:redis_health_check).and_return({
        status: "healthy",
        response_time_ms: 1.0,
        message: "Redis connection active and responsive"
      })
      allow_any_instance_of(HealthController).to receive(:queue_health_check).and_return({
        status: "healthy",
        response_time_ms: 1.0,
        message: "Queue system operational"
      })

      get '/health/ready'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      json = JSON.parse(response.body)
      expect(json).to have_key('status')
      expect(json).to have_key('checks')
      expect(json['checks']).to have_key('database')
      expect(json['checks']).to have_key('redis')
      expect(json['checks']).to have_key('queue')
      expect(json['status']).to eq('healthy')
    end

    it 'returns degraded status when services are down' do
      # Mock database failure
      allow_any_instance_of(HealthController).to receive(:database_health_check).and_return({
        status: "unhealthy",
        response_time_ms: 1.0,
        message: "Database connection failed"
      })
      allow_any_instance_of(HealthController).to receive(:redis_health_check).and_return({
        status: "healthy",
        response_time_ms: 1.0,
        message: "Redis connection active and responsive"
      })
      allow_any_instance_of(HealthController).to receive(:queue_health_check).and_return({
        status: "healthy",
        response_time_ms: 1.0,
        message: "Queue system operational"
      })

      get '/health/ready'

      expect(response).to have_http_status(:service_unavailable)

      json = JSON.parse(response.body)
      expect(json['status']).to eq('degraded')
      expect(json['checks']['database']['status']).to eq('unhealthy')
    end
  end
end
