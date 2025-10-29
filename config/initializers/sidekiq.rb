require "sidekiq"
# require 'sidekiq-scheduler'  # Temporarily disabled due to configuration issues

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Configure retry behavior
  config.retry_jobs = true
  config.dead_job_retry_in = 1.day
  config.dead_job_max_retries = 3

  # Configure job monitoring
  config.logger.level = Logger::INFO
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new

  # Load scheduler - temporarily disabled
  # config.on(:startup) do
  #   Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq.yml', __FILE__))
  #   SidekiqScheduler::Scheduler.instance.reload_schedule!
  # end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

# Configure global job options
Sidekiq.default_job_options = {
  "retry" => 3,
  "backtrace" => true,
  "dead" => true
}
