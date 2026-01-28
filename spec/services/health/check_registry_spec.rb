# frozen_string_literal: true

require "rails_helper"

RSpec.describe Health::CheckRegistry do
  describe ".ready" do
    it "returns an array of check instances" do
      checks = described_class.ready

      expect(checks).to be_an(Array)
      expect(checks.length).to eq(3)
    end

    it "includes Database, Redis, and Queue checks" do
      checks = described_class.ready
      class_names = checks.map { |c| c.class.name }

      expect(class_names).to include("Health::Checks::Database")
      expect(class_names).to include("Health::Checks::Redis")
      expect(class_names).to include("Health::Checks::Queue")
    end

    it "returns objects that respond to #call" do
      described_class.ready.each do |check|
        expect(check).to respond_to(:call)
      end
    end
  end

  describe ".detailed" do
    it "includes all ready checks plus Storage and ExternalApis" do
      checks = described_class.detailed
      class_names = checks.map { |c| c.class.name }

      expect(checks.length).to eq(5)
      expect(class_names).to include("Health::Checks::Storage")
      expect(class_names).to include("Health::Checks::ExternalApis")
    end

    it "is a superset of ready checks" do
      ready_names = described_class.ready.map { |c| c.class.name }
      detailed_names = described_class.detailed.map { |c| c.class.name }

      ready_names.each do |name|
        expect(detailed_names).to include(name)
      end
    end
  end
end
