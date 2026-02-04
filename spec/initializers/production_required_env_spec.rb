# frozen_string_literal: true

require "rails_helper"

RSpec.describe "production_required_env initializer" do
  let(:initializer_path) { Rails.root.join("config/initializers/production_required_env.rb") }
  let(:required_keys) do
    %w[
      DATABASE_URL
      SECRET_KEY_BASE
      APNS_KEY_ID
      APNS_TEAM_ID
      APNS_BUNDLE_ID
      APNS_KEY_CONTENT
      APPLE_BUNDLE_ID
      HEALTH_DIAGNOSTICS_TOKEN
      SIDEKIQ_USERNAME
      SIDEKIQ_PASSWORD
    ]
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    required_keys.each do |key|
      allow(ENV).to receive(:[]).with(key).and_return("set")
    end
  end

  it "raises in production when sidekiq credentials are missing" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    allow(ENV).to receive(:[]).with("SIDEKIQ_USERNAME").and_return(nil)
    allow(ENV).to receive(:[]).with("SIDEKIQ_PASSWORD").and_return(nil)

    expect { load initializer_path }.to raise_error(
      RuntimeError,
      /SIDEKIQ_USERNAME, SIDEKIQ_PASSWORD/
    )
  end

  it "does not raise outside production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))

    expect { load initializer_path }.not_to raise_error
  end
end
