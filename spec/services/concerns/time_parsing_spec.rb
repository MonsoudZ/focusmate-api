# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeParsing do
  describe ".parse_time" do
    context "with nil/blank values" do
      it "returns nil for nil" do
        expect(TimeParsing.parse_time(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(TimeParsing.parse_time("")).to be_nil
      end
    end

    context "with ISO8601 strings" do
      it "parses UTC timestamps" do
        result = TimeParsing.parse_time("2024-01-15T12:00:00Z")
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.utc.iso8601).to eq("2024-01-15T12:00:00Z")
      end

      it "parses timestamps with timezone offset" do
        result = TimeParsing.parse_time("2024-01-15T12:00:00-05:00")
        expect(result).to be_a(ActiveSupport::TimeWithZone)
      end
    end

    context "with Unix timestamps (seconds)" do
      it "parses 10-digit timestamps" do
        # 2024-01-15 12:00:00 UTC
        result = TimeParsing.parse_time(1705320000)
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.year).to eq(2024)
      end

      it "parses string timestamps" do
        result = TimeParsing.parse_time("1705320000")
        expect(result).to be_a(ActiveSupport::TimeWithZone)
      end
    end

    context "with Unix timestamps (milliseconds)" do
      it "parses 13-digit timestamps" do
        # 2024-01-15 12:00:00 UTC in milliseconds
        result = TimeParsing.parse_time(1705320000000)
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.year).to eq(2024)
      end
    end

    context "with Time objects" do
      it "returns the time in current timezone" do
        time = Time.new(2024, 1, 15, 12, 0, 0, "+00:00")
        result = TimeParsing.parse_time(time)
        expect(result).to be_a(ActiveSupport::TimeWithZone)
      end
    end

    context "with DateTime objects" do
      it "returns the time in current timezone" do
        datetime = DateTime.new(2024, 1, 15, 12, 0, 0)
        result = TimeParsing.parse_time(datetime)
        expect(result).to be_a(ActiveSupport::TimeWithZone)
      end
    end

    context "with invalid values" do
      it "returns nil for invalid strings" do
        expect(TimeParsing.parse_time("not-a-date")).to be_nil
      end

      it "returns nil for invalid types" do
        expect(TimeParsing.parse_time([])).to be_nil
      end
    end
  end

  describe ".parse_epoch" do
    it "parses seconds" do
      result = TimeParsing.parse_epoch(1705320000)
      expect(result.year).to eq(2024)
    end

    it "parses milliseconds" do
      result = TimeParsing.parse_epoch(1705320000000)
      expect(result.year).to eq(2024)
    end

    it "returns nil for blank values" do
      expect(TimeParsing.parse_epoch(nil)).to be_nil
      expect(TimeParsing.parse_epoch("")).to be_nil
    end
  end

  describe "as included module" do
    let(:test_class) do
      Class.new do
        include TimeParsing
      end
    end

    it "provides instance methods" do
      instance = test_class.new
      expect(instance.parse_time("2024-01-15T12:00:00Z")).to be_a(ActiveSupport::TimeWithZone)
    end

    it "provides class methods" do
      expect(test_class.parse_time("2024-01-15T12:00:00Z")).to be_a(ActiveSupport::TimeWithZone)
    end
  end
end
