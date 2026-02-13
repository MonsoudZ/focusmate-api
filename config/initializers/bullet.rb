# frozen_string_literal: true

if defined?(Bullet) && (Rails.env.development? || Rails.env.test?)
  Bullet.enable = true

  # Development settings - log and show alerts
  if Rails.env.development?
    Bullet.alert = true              # JavaScript popup
    Bullet.bullet_logger = true      # Log to log/bullet.log
    Bullet.console = true            # Browser console
    Bullet.rails_logger = true       # Rails log
    Bullet.add_footer = true         # Add footer to HTML pages
  end

  # Test settings - raise errors on N+1
  if Rails.env.test?
    Bullet.bullet_logger = true
    Bullet.raise = false             # Set to true to fail tests on N+1
    Bullet.unused_eager_loading_enable = false  # Can be noisy in tests
  end

  # Whitelist known acceptable N+1s (if any)
  # Bullet.add_whitelist type: :n_plus_one_query, class_name: "Task", association: :list
end
