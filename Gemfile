source "https://rubygems.org"

gem "rails", "~> 8.0.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

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

# Feature flags
gem "flipper"
gem "flipper-active_record"

# Error tracking
gem "sentry-ruby"
gem "sentry-rails"

# Structured logging
gem "lograge"

# Database migration safety
gem "strong_migrations"

# Timezone data for Windows
gem "tzinfo-data", platforms: %i[windows jruby]

# Rails 8 adapters
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

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
end
