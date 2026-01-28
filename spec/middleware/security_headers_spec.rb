# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::SecurityHeaders do
  let(:app) { ->(env) { [ 200, { "Content-Type" => "application/json" }, [ "ok" ] ] } }
  let(:middleware) { described_class.new(app) }
  let(:env) { Rack::MockRequest.env_for("/api/v1/test") }

  subject(:response) { middleware.call(env) }

  it "sets X-Content-Type-Options" do
    _, headers, = response
    expect(headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  it "sets X-Frame-Options" do
    _, headers, = response
    expect(headers["X-Frame-Options"]).to eq("DENY")
  end

  it "disables X-XSS-Protection" do
    _, headers, = response
    expect(headers["X-XSS-Protection"]).to eq("0")
  end

  it "sets Referrer-Policy" do
    _, headers, = response
    expect(headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
  end

  it "sets Permissions-Policy" do
    _, headers, = response
    expect(headers["Permissions-Policy"]).to include("camera=()")
  end

  it "sets Content-Security-Policy" do
    _, headers, = response
    expect(headers["Content-Security-Policy"]).to eq("default-src 'none'; frame-ancestors 'none'")
  end

  it "sets Cache-Control to no-store by default" do
    _, headers, = response
    expect(headers["Cache-Control"]).to eq("no-store")
  end

  it "does not override existing Cache-Control" do
    app_with_cache = ->(env) { [ 200, { "Cache-Control" => "public, max-age=3600" }, [ "ok" ] ] }
    mw = described_class.new(app_with_cache)
    _, headers, = mw.call(env)
    expect(headers["Cache-Control"]).to eq("public, max-age=3600")
  end
end
