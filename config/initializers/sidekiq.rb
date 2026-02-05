# frozen_string_literal: true

require "sidekiq"

# Only configure Sidekiq if Redis is available
if ENV["REDIS_URL"].present?
  # ===================
  # Server Configuration (runs in Sidekiq process)
  # ===================
  Sidekiq.configure_server do |config|
    config.redis = {
      url: ENV.fetch("REDIS_URL"),
      network_timeout: 5,
      pool_timeout: 5
    }

    # JSON logging for production
    if Rails.env.production?
      config.logger.level = Logger::INFO
      config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    end

    # Load cron schedule on startup (if sidekiq-cron is available)
    config.on(:startup) do
      schedule_file = Rails.root.join("config", "sidekiq_schedule.yml")

      if File.exist?(schedule_file) && defined?(Sidekiq::Cron)
        begin
          schedule = YAML.safe_load(File.read(schedule_file), aliases: false) || {}
          raise "Sidekiq schedule must be a hash" unless schedule.is_a?(Hash)

          Sidekiq::Cron::Job.load_from_hash(schedule)
          Rails.logger.info("Sidekiq-Cron: Loaded #{schedule.keys.count} scheduled jobs")
        rescue StandardError => e
          Rails.logger.error(
            event: "sidekiq_cron_schedule_load_failed",
            error_class: e.class.name,
            error_message: e.message
          )
          Sentry.capture_exception(e, extra: { schedule_file: schedule_file.to_s }) if defined?(Sentry)
        end
      end
    end

    # Error reporting to Sentry
    config.error_handlers << proc do |ex, ctx_hash|
      Sentry.capture_exception(ex, extra: ctx_hash) if defined?(Sentry)
    end

    # Death handler - alert when jobs go to dead queue
    config.death_handlers << proc do |job, ex|
      Rails.logger.error(
        event: "sidekiq_job_dead",
        job_class: job["class"],
        job_id: job["jid"],
        error: ex.message,
        args: job["args"]
      )

      if defined?(Sentry)
        Sentry.capture_message(
          "Sidekiq job moved to dead queue: #{job['class']}",
          level: :error,
          extra: {
            job_class: job["class"],
            job_id: job["jid"],
            error: ex.message,
            args: job["args"],
            failed_at: Time.current.iso8601
          }
        )
      end
    end
  end

  # ===================
  # Client Configuration (runs in Rails process)
  # ===================
  Sidekiq.configure_client do |config|
    config.redis = {
      url: ENV.fetch("REDIS_URL"),
      network_timeout: 5,
      pool_timeout: 5
    }
  end

  # ===================
  # Default Job Options
  # ===================
  Sidekiq.default_job_options = {
    "retry" => 3,
    "backtrace" => 10,
    "dead" => true
  }

else
  Rails.logger.info("Sidekiq: REDIS_URL not configured, skipping Sidekiq setup")
end
