# frozen_string_literal: true

# TimeParsing provides utilities for parsing various time formats.
#
# Handles:
#   - ISO8601 strings ("2024-01-01T12:00:00Z")
#   - Unix timestamps in seconds (1704110400)
#   - Unix timestamps in milliseconds (1704110400000)
#   - Ruby Time/DateTime objects
#   - nil/blank values (returns nil)
#
# Usage in a service:
#   class TaskCreationService
#     include TimeParsing
#
#     def call
#       due_at = parse_time(params[:due_at])
#     end
#   end
#
# Usage as class methods:
#   TimeParsing.parse_time("2024-01-01T12:00:00Z")
#   TimeParsing.parse_epoch(1704110400)
#
module TimeParsing
  extend ActiveSupport::Concern

  included do
    # Make methods available as both instance and class methods
  end

  class_methods do
    def parse_time(value)
      TimeParsing.parse_time(value)
    end

    def parse_epoch(value)
      TimeParsing.parse_epoch(value)
    end
  end

  # Parse a time value from various formats
  #
  # @param value [String, Integer, Time, DateTime, nil] The value to parse
  # @return [ActiveSupport::TimeWithZone, nil] The parsed time or nil
  #
  def parse_time(value)
    TimeParsing.parse_time(value)
  end

  # Parse a Unix timestamp (seconds or milliseconds)
  #
  # @param value [Integer, String] Unix timestamp
  # @return [ActiveSupport::TimeWithZone, nil] The parsed time or nil
  #
  def parse_epoch(value)
    TimeParsing.parse_epoch(value)
  end

  # Module-level methods for direct access
  class << self
    def parse_time(value)
      return nil if value.blank?

      case value
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.in_time_zone
      when Integer
        parse_epoch(value)
      when /\A\d{10,13}\z/
        parse_epoch(value.to_i)
      when String
        parse_string_time(value)
      else
        nil
      end
    rescue ArgumentError, TypeError => e
      Rails.logger.debug("TimeParsing: Failed to parse '#{value}': #{e.message}")
      nil
    end

    def parse_epoch(value)
      return nil if value.blank?

      timestamp = value.to_i

      # Detect milliseconds vs seconds
      # Millisecond timestamps are > 10 digits (after year ~2001)
      timestamp = timestamp / 1000 if timestamp > 9_999_999_999

      Time.at(timestamp).in_time_zone
    rescue ArgumentError, RangeError => e
      Rails.logger.debug("TimeParsing: Failed to parse epoch '#{value}': #{e.message}")
      nil
    end

    private

    def parse_string_time(value)
      # Try ISO8601 first (most common API format)
      Time.iso8601(value).in_time_zone
    rescue ArgumentError
      # Fall back to flexible parsing
      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end