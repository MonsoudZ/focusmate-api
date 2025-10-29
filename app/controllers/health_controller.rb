# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def live
    head :ok
  end

  def ready
    checks = {
      db: database_healthy?,
      redis: redis_healthy?,
      queue: queue_healthy?
    }

    if checks.values.all?
      render json: { status: "ok", checks: checks }
    else
      render json: { status: "degraded", checks: checks }, status: :service_unavailable
    end
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue => e
    Rails.logger.error "Database health check failed: #{e.message}"
    false
  end

  def redis_healthy?
    Redis.new.ping == "PONG"
  rescue => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    false
  end

  def queue_healthy?
    Sidekiq.redis_info.present?
  rescue => e
    Rails.logger.error "Queue health check failed: #{e.message}"
    false
  end
end
