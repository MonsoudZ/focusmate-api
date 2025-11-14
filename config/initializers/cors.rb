# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Configure allowed origins via environment variable
    # Example: ALLOWED_ORIGINS=https://app.example.com,https://www.example.com
    # For development, you can use: ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
    origins_list = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)

    # If no origins configured, allow all in development/test, deny all in production
    if origins_list.empty?
      if Rails.env.development? || Rails.env.test?
        origins "*"
      else
        # In production, require explicit configuration
        Rails.logger.warn "[CORS] WARNING: No ALLOWED_ORIGINS configured. CORS will deny all cross-origin requests."
        origins [] # Deny all
      end
    else
      origins origins_list
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 3600
  end
end
