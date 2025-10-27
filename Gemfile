source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Authentication with Devise and JWT
gem "devise"
gem "devise-jwt"

# Authorization with Pundit
gem "pundit"

# Background job processing
gem "sidekiq"
gem "sidekiq-cron"
gem "sidekiq-scheduler" # For scheduled/recurring jobs

# Redis for caching and Sidekiq backend
gem "redis", "~> 5.0"

# Rate limiting and security
gem "rack-attack"

# Feature flags
gem "flipper"
gem "flipper-active_record"

# APNs push notifications with HTTP/2 support
gem "apnotic"    # APNs HTTP/2 client
gem "http-2"     # HTTP/2 client for APNs
gem "jwt"        # JWT token generation for APNs

# JSON API serialization
gem "jsonapi-serializer"

# OpenAPI specification and validation
gem "committee"  # Response validation against OpenAPI schema
gem "rswag"      # OpenAPI/Swagger documentation generation

# Geocoding for location-based features
gem "geocoder"

# Firebase Cloud Messaging for push notifications
gem "fcm"

# Error tracking and monitoring
gem "sentry-ruby"
gem "sentry-rails"

# Structured logging
gem "lograge"

# Database migration safety
gem "strong_migrations"

# Mutation testing
gem "mutant-rspec", require: false, group: :test

# HTTP client for API calls
gem "httparty"

# Email testing in development
gem "mailcatcher", group: :development

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Code quality and dead code analysis
  gem "rubycritic", require: false
  gem "traceroute", require: false
  gem "deep-cover", require: false
  gem "bundler-audit", require: false

  # PR quality gates
  gem "danger", require: false

  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "mocha"
  gem "simplecov", require: false
end

# Environment variables
gem "dotenv-rails", groups: [ :development, :test ]
