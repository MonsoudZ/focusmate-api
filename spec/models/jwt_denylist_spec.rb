# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtDenylist do
  it "uses the jwt_denylists table" do
    expect(described_class.table_name).to eq("jwt_denylists")
  end

  it "includes Devise JWT denylist strategy" do
    expect(described_class.ancestors).to include(Devise::JWT::RevocationStrategies::Denylist)
  end

  it "can store a revoked token" do
    jti = SecureRandom.uuid
    entry = described_class.create!(jti: jti, exp: 1.day.from_now)
    expect(entry).to be_persisted
    expect(described_class.exists?(jti: jti)).to be true
  end
end
