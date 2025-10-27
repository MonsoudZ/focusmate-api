# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  
  # Add custom payload to logs
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id: Current.user&.id,
      params: controller.request.filtered_parameters.except('controller', 'action'),
      ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent
    }
  end
  
  # Customize log format
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      level: 'INFO',
      service: 'focusmate-api'
    }
  end
end
