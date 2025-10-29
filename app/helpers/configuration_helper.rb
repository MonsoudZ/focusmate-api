# frozen_string_literal: true

module ConfigurationHelper
  class ConfigurationError < StandardError; end
  class ValidationError < ConfigurationError; end

  # Load configuration from YAML file with enhanced error handling
  def self.config
    @config ||= load_configuration
  end

  # Reload configuration (useful for testing or config changes)
  def self.reload!
    @config = nil
    load_configuration
  end

  # Get configuration value with dot notation and validation
  def self.get(key_path, default = nil, type: nil, validate: true)
    keys = key_path.split(".")
    value = config

    keys.each do |key|
      return default unless value.is_a?(Hash)
      value = value[key]
    end

    result = value || default

    # Type validation if specified
    if validate && type && result != default
      validate_type(result, type, key_path)
    end

    result
  end

  # Get configuration value with environment variable override
  def self.get_with_env_override(key_path, env_var, default = nil, type: nil)
    env_value = ENV[env_var]
    if env_value.present?
      parsed_value = parse_env_value(env_value, type)
      Rails.logger.info "Configuration override: #{key_path} = #{parsed_value} (from #{env_var})"
      parsed_value
    else
      get(key_path, default, type: type)
    end
  end

  # Validate configuration on startup
  def self.validate_configuration!
    errors = []
    
    # Validate required configurations
    required_configs = [
      "database.default_page_size",
      "database.max_page_size"
    ]

    required_configs.each do |key|
      value = get(key, nil, validate: false)
      if value.nil?
        errors << "Required configuration missing: #{key}"
      end
    end

    # Validate rate limits are positive (only if they exist)
    rate_limits = [
      "rate_limits.api.limit",
      "rate_limits.auth.limit",
      "rate_limits.password_reset.limit"
    ]

    rate_limits.each do |key|
      value = get(key, nil, validate: false)
      if value.present? && value <= 0
        errors << "Invalid rate limit configuration: #{key} must be positive (got #{value})"
      end
    end

    # Validate page sizes
    default_page_size = get("database.default_page_size", 0, type: :integer, validate: false)
    max_page_size = get("database.max_page_size", 0, type: :integer, validate: false)
    
    if default_page_size > max_page_size
      errors << "Invalid page size configuration: default_page_size (#{default_page_size}) cannot be greater than max_page_size (#{max_page_size})"
    end

    # Validate location radius
    default_radius = get("location.default_radius_meters", 0, type: :integer, validate: false)
    max_radius = get("location.max_radius_meters", 0, type: :integer, validate: false)
    
    if default_radius > max_radius
      errors << "Invalid location radius configuration: default_radius (#{default_radius}) cannot be greater than max_radius (#{max_radius})"
    end

    if errors.any?
      error_message = "Configuration validation failed:\n" + errors.join("\n")
      Rails.logger.error error_message
      raise ValidationError, error_message
    end

    Rails.logger.info "Configuration validation passed"
    true
  end

  private

  def self.load_configuration
    config_file = Rails.root.join("config", "application.yml")
    
    if File.exist?(config_file)
      begin
        yaml_content = YAML.load_file(config_file, aliases: true)
        config = yaml_content[Rails.env] || yaml_content["default"] || {}
        
        Rails.logger.info "Configuration loaded from #{config_file} for environment: #{Rails.env}"
        config
      rescue Psych::SyntaxError => e
        Rails.logger.error "YAML syntax error in configuration file: #{e.message}"
        raise ConfigurationError, "Invalid YAML syntax in configuration file: #{e.message}"
      rescue => e
        Rails.logger.error "Error loading configuration: #{e.message}"
        raise ConfigurationError, "Failed to load configuration: #{e.message}"
      end
    else
      Rails.logger.warn "Configuration file not found: #{config_file}. Using defaults."
      {}
    end
  end

  def self.validate_type(value, type, key_path)
    case type
    when :integer
      unless value.is_a?(Integer) || value.to_s.match?(/^\d+$/)
        raise ValidationError, "Configuration #{key_path} must be an integer (got #{value.class}: #{value})"
      end
    when :string
      unless value.is_a?(String)
        raise ValidationError, "Configuration #{key_path} must be a string (got #{value.class}: #{value})"
      end
    when :boolean
      unless [true, false, "true", "false", 1, 0].include?(value)
        raise ValidationError, "Configuration #{key_path} must be a boolean (got #{value.class}: #{value})"
      end
    when :array
      unless value.is_a?(Array)
        raise ValidationError, "Configuration #{key_path} must be an array (got #{value.class}: #{value})"
      end
    when :hash
      unless value.is_a?(Hash)
        raise ValidationError, "Configuration #{key_path} must be a hash (got #{value.class}: #{value})"
      end
    end
  end

  def self.parse_env_value(value, type)
    case type
    when :integer
      value.to_i
    when :boolean
      %w[true 1 yes on].include?(value.downcase)
    when :array
      value.split(',').map(&:strip)
    when :hash
      JSON.parse(value) rescue value
    else
      value
    end
  rescue => e
    Rails.logger.warn "Failed to parse environment value '#{value}' as #{type}: #{e.message}"
    value
  end

  # Task configuration
  def self.task_title_max_length
    get("task.title_max_length", 255, type: :integer)
  end

  def self.task_note_max_length
    get("task.note_max_length", 1000, type: :integer)
  end

  def self.task_cache_expiry
    minutes = get("task.cache_expiry_minutes", 5, type: :integer)
    minutes.minutes
  end

  # Performance grades
  def self.performance_grade(completion_rate)
    grades = get("performance.grades", {}, type: :hash)
    
    # Validate completion rate
    unless completion_rate.is_a?(Numeric) && completion_rate >= 0 && completion_rate <= 1
      raise ValidationError, "Completion rate must be a number between 0 and 1 (got #{completion_rate})"
    end
    
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
    get("rate_limits.api.limit", 100, type: :integer)
  end

  def self.api_rate_period
    value = get("rate_limits.api.period", "1.minute")
    value.is_a?(String) ? parse_time_period(value) : value
  end

  def self.auth_rate_limit
    get("rate_limits.auth.limit", 5, type: :integer)
  end

  def self.auth_rate_period
    value = get("rate_limits.auth.period", "1.minute")
    value.is_a?(String) ? parse_time_period(value) : value
  end

  def self.password_reset_rate_limit
    get("rate_limits.password_reset.limit", 3, type: :integer)
  end

  def self.password_reset_rate_period
    value = get("rate_limits.password_reset.period", "1.hour")
    value.is_a?(String) ? parse_time_period(value) : value
  end

  # Time periods
  def self.recent_activity_period
    value = get("time_periods.recent_activity", 1.week)
    value.is_a?(String) ? parse_time_period(value) : value
  end

  def self.upcoming_deadlines_period
    value = get("time_periods.upcoming_deadlines", 1.week)
    value.is_a?(String) ? parse_time_period(value) : value
  end

  def self.cache_expiry
    value = get("time_periods.cache_expiry", 5.minutes)
    value.is_a?(String) ? parse_time_period(value) : value
  end

  # Safe time period parsing
  def self.parse_time_period(period_string)
    case period_string.downcase.strip
    when /^(\d+)\s*minutes?$/
      $1.to_i.minutes
    when /^(\d+)\s*hours?$/
      $1.to_i.hours
    when /^(\d+)\s*days?$/
      $1.to_i.days
    when /^(\d+)\s*weeks?$/
      $1.to_i.weeks
    when /^(\d+)\s*months?$/
      $1.to_i.months
    when /^(\d+)\s*years?$/
      $1.to_i.years
    else
      # Fallback to default if parsing fails
      1.week
    end
  end

  # Database configuration
  def self.default_page_size
    get("database.default_page_size", 20, type: :integer)
  end

  def self.max_page_size
    get("database.max_page_size", 100, type: :integer)
  end

  # Notification configuration
  def self.default_notification_interval
    get("notifications.default_interval_minutes", 10, type: :integer)
  end

  def self.max_notification_retries
    get("notifications.max_retries", 3, type: :integer)
  end

  # Location configuration
  def self.default_location_radius
    get("location.default_radius_meters", 100, type: :integer)
  end

  def self.max_location_radius
    get("location.max_radius_meters", 10000, type: :integer)
  end

  # Environment variable overrides for production
  def self.api_rate_limit_with_override
    get_with_env_override("rate_limits.api.limit", "API_RATE_LIMIT", 100, type: :integer)
  end

  def self.database_max_page_size_with_override
    get_with_env_override("database.max_page_size", "MAX_PAGE_SIZE", 100, type: :integer)
  end

  # Configuration summary for debugging
  def self.configuration_summary
    {
      environment: Rails.env,
      config_file_exists: File.exist?(Rails.root.join("config", "application.yml")),
      loaded_at: @config ? Time.current : nil,
      task_config: {
        title_max_length: task_title_max_length,
        note_max_length: task_note_max_length,
        cache_expiry_minutes: task_cache_expiry / 1.minute
      },
      rate_limits: {
        api_limit: api_rate_limit,
        auth_limit: auth_rate_limit,
        password_reset_limit: password_reset_rate_limit
      },
      database: {
        default_page_size: default_page_size,
        max_page_size: max_page_size
      },
      notifications: {
        default_interval_minutes: default_notification_interval,
        max_retries: max_notification_retries
      },
      location: {
        default_radius_meters: default_location_radius,
        max_radius_meters: max_location_radius
      }
    }
  end
end
