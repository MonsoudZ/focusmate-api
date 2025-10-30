require 'rails_helper'

RSpec.describe JsonParserErrorHandler do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  describe '#call' do
    it 'passes through normal requests' do
      env = {}
      status, headers, body = middleware.call(env)

      expect(status).to eq(200)
      expect(body).to eq(['OK'])
    end

    it 'returns 400 when ActionDispatch::Http::Parameters::ParseError is raised' do
      error_app = ->(env) { raise ActionDispatch::Http::Parameters::ParseError.new('Invalid JSON') }
      error_middleware = described_class.new(error_app)

      status, headers, body = error_middleware.call({})

      expect(status).to eq(400)
      expect(headers['Content-Type']).to eq('application/json')
    end

    it 'returns JSON error message when parse error occurs' do
      error_app = ->(env) { raise ActionDispatch::Http::Parameters::ParseError.new('Invalid JSON') }
      error_middleware = described_class.new(error_app)

      status, headers, body = error_middleware.call({})

      json_response = JSON.parse(body.first)
      expect(json_response).to have_key('error')
      expect(json_response['error']['message']).to eq('Invalid JSON format')
    end

    it 'catches parse errors and returns proper response format' do
      error_app = ->(env) { raise ActionDispatch::Http::Parameters::ParseError.new('Bad JSON') }
      error_middleware = described_class.new(error_app)

      status, headers, body = error_middleware.call({})

      expect(status).to eq(400)
      expect(headers).to have_key('Content-Type')
      expect(body).to be_an(Array)
      expect(body.length).to eq(1)
    end

    it 'does not catch other types of errors' do
      error_app = ->(env) { raise StandardError.new('Some other error') }
      error_middleware = described_class.new(error_app)

      expect {
        error_middleware.call({})
      }.to raise_error(StandardError, 'Some other error')
    end
  end
end
