# frozen_string_literal: true

require "rails_helper"

RSpec.describe Health::System do
  describe ".version" do
    it "returns a string" do
      expect(described_class.version).to be_a(String)
    end

    it "returns config version when available" do
      allow(Rails.application.config).to receive(:respond_to?).and_call_original
      allow(Rails.application.config).to receive(:respond_to?).with(:version).and_return(true)
      allow(Rails.application.config).to receive(:respond_to?).with(:version, anything).and_return(true)
      allow(Rails.application.config).to receive(:version).and_return("1.2.3")

      expect(described_class.version).to eq("1.2.3")
    end

    it "falls back to VERSION file" do
      allow(Rails.application.config).to receive(:respond_to?).with(:version).and_return(false)
      version_path = Rails.root.join("VERSION")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(version_path).and_return(true)
      allow(File).to receive(:read).with(version_path).and_return("2.0.0\n")

      expect(described_class.version).to eq("2.0.0")
    end

    it "returns 'unknown' when no version source exists" do
      allow(Rails.application.config).to receive(:respond_to?).with(:version).and_return(false)
      version_path = Rails.root.join("VERSION")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(version_path).and_return(false)

      expect(described_class.version).to eq("unknown")
    end
  end

  describe ".uptime_seconds" do
    it "returns nil when boot_time is not configured" do
      allow(Rails.application.config).to receive(:respond_to?).with(:boot_time).and_return(false)

      expect(described_class.uptime_seconds).to be_nil
    end

    it "returns seconds since boot when boot_time is set" do
      boot = 60.seconds.ago
      allow(Rails.application.config).to receive(:respond_to?).and_call_original
      allow(Rails.application.config).to receive(:respond_to?).with(:boot_time).and_return(true)
      allow(Rails.application.config).to receive(:respond_to?).with(:boot_time, anything).and_return(true)
      allow(Rails.application.config).to receive(:boot_time).and_return(boot)

      uptime = described_class.uptime_seconds
      expect(uptime).to be_a(Integer)
      expect(uptime).to be >= 59
      expect(uptime).to be <= 62
    end
  end

  describe ".memory" do
    it "returns nil when GetProcessMem is not available" do
      hide_const("GetProcessMem") if defined?(GetProcessMem)

      expect(described_class.memory).to be_nil
    end

    it "returns memory info when GetProcessMem is available" do
      stub_const("GetProcessMem", Class.new)
      mem_instance = double("GetProcessMem", mb: 128.567)
      allow(GetProcessMem).to receive(:new).and_return(mem_instance)

      result = described_class.memory
      expect(result).to eq({ rss_mb: 128.57 })
    end
  end
end
