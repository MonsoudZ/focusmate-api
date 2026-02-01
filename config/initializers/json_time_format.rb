# frozen_string_literal: true

# Ensure all timestamps in JSON responses use ISO8601 format consistently.
# This removes the need to call .iso8601 manually in serializers.

ActiveSupport::JSON::Encoding.time_precision = 0
