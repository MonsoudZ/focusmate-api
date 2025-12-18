require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #live' do
    it 'returns HTTP 200 OK' do
      get :live
      expect(response).to have_http_status(:ok)
    end

    it 'does not require authentication' do
      # No authentication headers
      get :live
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #ready' do
    it 'returns HTTP 200 OK when all checks pass' do
      get :ready
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON response with health status' do
      get :ready
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('status')
      expect(json_response).to have_key('timestamp')
      expect(json_response).to have_key('duration_ms')
      expect(json_response).to have_key('version')
      expect(json_response).to have_key('environment')
      expect(json_response).to have_key('checks')
    end

    it 'includes database, redis, and queue checks' do
      get :ready
      json_response = JSON.parse(response.body)

      expect(json_response['checks']).to have_key('database')
      expect(json_response['checks']).to have_key('redis')
      expect(json_response['checks']).to have_key('queue')
    end

    it 'returns healthy status when all services are operational' do
      get :ready
      json_response = JSON.parse(response.body)

      expect(json_response['status']).to eq('healthy')
      expect(json_response['checks']['database']['status']).to eq('healthy')
    end

    it 'does not require authentication' do
      get :ready
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #detailed' do
    it 'returns HTTP 200 OK' do
      get :detailed
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON response with detailed health information' do
      get :detailed
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('status')
      expect(json_response).to have_key('timestamp')
      expect(json_response).to have_key('duration_ms')
      expect(json_response).to have_key('version')
      expect(json_response).to have_key('environment')
      expect(json_response).to have_key('uptime')
      expect(json_response).to have_key('memory_usage')
      expect(json_response).to have_key('checks')
    end

    it 'includes additional checks beyond basic ready check' do
      get :detailed
      json_response = JSON.parse(response.body)

      expect(json_response['checks']).to have_key('database')
      expect(json_response['checks']).to have_key('redis')
      expect(json_response['checks']).to have_key('queue')
      expect(json_response['checks']).to have_key('storage')
      expect(json_response['checks']).to have_key('external_apis')
    end
  end

  describe 'GET #metrics' do
    it 'returns HTTP 200 OK' do
      get :metrics
      expect(response).to have_http_status(:ok)
    end

    it 'returns metrics in monitoring-friendly format' do
      get :metrics
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('health_status')
      expect(json_response).to have_key('database_status')
      expect(json_response).to have_key('redis_status')
      expect(json_response).to have_key('queue_status')
      expect(json_response).to have_key('timestamp')
    end

    it 'returns numeric status values' do
      get :metrics
      json_response = JSON.parse(response.body)

      expect([ 0, 1 ]).to include(json_response['health_status'])
      expect([ 0, 1 ]).to include(json_response['database_status'])
      expect([ 0, 1 ]).to include(json_response['redis_status'])
      expect([ 0, 1 ]).to include(json_response['queue_status'])
    end
  end

  describe 'private methods' do
    describe '#database_health_check' do
      it 'returns healthy status when database is accessible' do
        result = controller.send(:database_health_check)

        expect(result[:status]).to eq('healthy')
        expect(result).to have_key(:response_time_ms)
        expect(result).to have_key(:message)
      end

      it 'returns unhealthy status when database is not accessible' do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError.new('Connection failed'))

        result = controller.send(:database_health_check)

        expect(result[:status]).to eq('unhealthy')
        expect(result).to have_key(:error)
      end
    end

    describe '#redis_health_check' do
      it 'returns healthy status when Redis responds to ping' do
        result = controller.send(:redis_health_check)

        expect(result[:status]).to eq('healthy')
        expect(result).to have_key(:response_time_ms)
      end
    end

    describe '#queue_health_check' do
      it 'returns status with queue details' do
        result = controller.send(:queue_health_check)

        expect(result).to have_key(:status)
        expect(result).to have_key(:response_time_ms)
      end
    end

    describe '#storage_health_check' do
      it 'returns health status for storage' do
        result = controller.send(:storage_health_check)

        expect(result).to have_key(:status)
        expect(result).to have_key(:response_time_ms)
        expect(result).to have_key(:message)
      end
    end

    describe '#external_apis_health_check' do
      it 'returns health status for external APIs' do
        result = controller.send(:external_apis_health_check)

        expect(result).to have_key(:status)
        expect(result).to have_key(:response_time_ms)
      end
    end
  end
end
