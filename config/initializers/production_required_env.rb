# frozen_string_literal: true

# Validate required environment variables in production
# This provides a clearer error message than ENV.fetch failures
return unless Rails.env.production?

required = %w[DATABASE_URL SECRET_KEY_BASE]
missing = required.select { |k| ENV[k].blank? }

if missing.any?
  raise "Missing required env vars in production: #{missing.join(', ')}"
end

