# frozen_string_literal: true

module ConfigurationHelper
  # Load configuration from YAML file
  def self.config
    @config ||= begin
      config_file = Rails.root.join("config", "application.yml")
      if File.exist?(config_file)
        YAML.load_file(config_file, aliases: true)[Rails.env] || YAML.load_file(config_file, aliases: true)["default"]
      else
        {}
      end
    end
  end

  # Get configuration value with dot notation
  def self.get(key_path, default = nil)
    keys = key_path.split(".")
    value = config

    keys.each do |key|
      return default unless value.is_a?(Hash)
      value = value[key]
    end

    value || default
  end

  # Task configuration
  def self.task_title_max_length
    get("task.title_max_length", 255)
  end

  def self.task_note_max_length
    get("task.note_max_length", 1000)
  end

  def self.task_cache_expiry
    get("task.cache_expiry_minutes", 5).minutes
  end

  # Performance grades
  def self.performance_grade(completion_rate)
    grades = get("performance.grades", {})
    case completion_rate
    when grades["a"] then "A"
    when grades["b"] then "B"
    when grades["c"] then "C"
    when grades["d"] then "D"
    else "F"
    end
  end

  # Rate limiting
  def self.api_rate_limit
    get("rate_limits.api.limit", 100)
  end

  def self.api_rate_period
    get("rate_limits.api.period", 1.minute)
  end

  def self.auth_rate_limit
    get("rate_limits.auth.limit", 5)
  end

  def self.auth_rate_period
    get("rate_limits.auth.period", 1.minute)
  end

  def self.password_reset_rate_limit
    get("rate_limits.password_reset.limit", 3)
  end

  def self.password_reset_rate_period
    get("rate_limits.password_reset.period", 1.hour)
  end

  # Time periods
  def self.recent_activity_period
    value = get("time_periods.recent_activity", 1.week)
    value.is_a?(String) ? eval(value) : value
  end

  def self.upcoming_deadlines_period
    value = get("time_periods.upcoming_deadlines", 1.week)
    value.is_a?(String) ? eval(value) : value
  end

  def self.cache_expiry
    value = get("time_periods.cache_expiry", 5.minutes)
    value.is_a?(String) ? eval(value) : value
  end

  # Database configuration
  def self.default_page_size
    get("database.default_page_size", 20)
  end

  def self.max_page_size
    get("database.max_page_size", 100)
  end

  # Notification configuration
  def self.default_notification_interval
    get("notifications.default_interval_minutes", 10)
  end

  def self.max_notification_retries
    get("notifications.max_retries", 3)
  end

  # Location configuration
  def self.default_location_radius
    get("location.default_radius_meters", 100)
  end

  def self.max_location_radius
    get("location.max_radius_meters", 10000)
  end
end
