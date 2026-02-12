source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

gem "apple_id"
# Authentication
gem "bcrypt", "~> 3.1.7"
gem "devise"
gem "devise-jwt"

# Authorization
gem "pundit"

# Background jobs
gem "sidekiq"

# Redis
gem "redis", "~> 5.0"

# Rate limiting
gem "rack-attack"

# CORS
gem "rack-cors"

# Error tracking
gem "sentry-ruby"
gem "sentry-rails"

# Structured logging
gem "lograge"

# Database migration safety
gem "strong_migrations"

# Timezone data for Windows
gem "tzinfo-data", platforms: %i[windows jruby]

# Performance
gem "bootsnap", require: false

# Deployment
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubycritic", require: false
  gem "bundler-audit", require: false
  gem "danger", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "dotenv-rails"
  gem "bullet"  # N+1 query detection
  gem "benchmark-ips"  # Benchmarking
  gem "benchmark", require: false  # Extracted from default gems in Ruby 4.0
end

gem "rack-timeout", "~> 0.7"
gem "sidekiq-cron", "~> 1.12"
gem "apnotic"
