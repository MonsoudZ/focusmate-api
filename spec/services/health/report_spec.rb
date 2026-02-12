# frozen_string_literal: true

require "rails_helper"

RSpec.describe Health::Report do
  let(:healthy_result) do
    { name: "test", status: "healthy", response_time_ms: 1.0, message: "OK" }
  end
  let(:unhealthy_result) do
    { name: "test", status: "unhealthy", response_time_ms: nil, message: "Connection refused" }
  end

  describe ".live" do
    it "returns ok: true" do
      expect(described_class.live).to eq({ ok: true })
    end
  end

  describe ".ready" do
    it "returns a report with status, timestamp, duration_ms, and checks" do
      report = described_class.ready

      expect(report).to have_key(:status)
      expect(report).to have_key(:timestamp)
      expect(report).to have_key(:duration_ms)
      expect(report).to have_key(:checks)
      expect(report[:checks]).to be_an(Array)
    end

    it "reports healthy when all checks pass" do
      healthy_check = instance_double("Health::Checks::Base", call: healthy_result)
      allow(Health::CheckRegistry).to receive(:ready).and_return([ healthy_check ])

      report = described_class.ready
      expect(report[:status]).to eq("healthy")
    end

    it "reports degraded when any check fails" do
      healthy_check = instance_double("Health::Checks::Base", call: healthy_result)
      unhealthy_check = instance_double("Health::Checks::Base", call: unhealthy_result)
      allow(Health::CheckRegistry).to receive(:ready).and_return([ healthy_check, unhealthy_check ])

      report = described_class.ready
      expect(report[:status]).to eq("degraded")
    end

    it "does not include system info" do
      report = described_class.ready

      expect(report).not_to have_key(:version)
      expect(report).not_to have_key(:environment)
      expect(report).not_to have_key(:uptime_seconds)
    end
  end

  describe ".detailed" do
    it "includes system information" do
      report = described_class.detailed

      expect(report).to have_key(:version)
      expect(report).to have_key(:environment)
      expect(report).to have_key(:uptime_seconds)
      expect(report).to have_key(:memory)
    end

    it "includes all check results" do
      report = described_class.detailed

      expect(report[:checks]).to be_an(Array)
      expect(report[:checks].length).to eq(4) # ready(2) + storage + external_apis
    end
  end

  describe ".metrics" do
    it "returns numeric health indicators" do
      healthy_check = instance_double("Health::Checks::Base",
        call: { name: "database", status: "healthy" })
      queue_check = instance_double("Health::Checks::Base",
        call: { name: "queue", status: "healthy" })
      allow(Health::CheckRegistry).to receive(:ready).and_return([ healthy_check, queue_check ])

      metrics = described_class.metrics

      expect(metrics[:health]).to eq(1)
      expect(metrics[:database]).to eq(1)
      expect(metrics[:queue]).to eq(1)
      expect(metrics[:timestamp]).to be_a(Integer)
    end

    it "returns 0 for unhealthy checks" do
      db_check = instance_double("Health::Checks::Base",
        call: { name: "database", status: "unhealthy" })
      queue_check = instance_double("Health::Checks::Base",
        call: { name: "queue", status: "healthy" })
      allow(Health::CheckRegistry).to receive(:ready).and_return([ db_check, queue_check ])

      metrics = described_class.metrics

      expect(metrics[:health]).to eq(0) # overall degraded
      expect(metrics[:database]).to eq(0)
      expect(metrics[:queue]).to eq(1)
    end
  end

  describe ".http_status" do
    it "returns :ok for healthy reports" do
      expect(described_class.http_status({ status: "healthy" })).to eq(:ok)
    end

    it "returns :service_unavailable for degraded reports" do
      expect(described_class.http_status({ status: "degraded" })).to eq(:service_unavailable)
    end
  end
end
