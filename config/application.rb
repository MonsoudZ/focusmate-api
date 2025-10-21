require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FocusmateApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    
    # Enable ActionCable for real-time features
    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins = [/http:\/\/localhost.*/, /https:\/\/.*\.ngrok\.io/, /https:\/\/.*\.ngrok-free\.dev/]

    # Add back cookies and session middleware so Devise failure app can operate without sessions error
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "_focusmate_api_session", secure: false, httponly: true, same_site: :lax

    # Configure Active Job to use Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # Add Rack::Attack middleware
    config.middleware.use Rack::Attack
  end
end
