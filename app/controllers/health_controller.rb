# frozen_string_literal: true

class HealthController < ActionController::API
  def live
    render json: Health::Report.live, status: :ok
  end

  def ready
    report = Health::Report.ready
    render json: report, status: Health::Report.http_status(report)
  end

  def detailed
    report = Health::Report.detailed
    render json: report, status: Health::Report.http_status(report)
  end

  def metrics
    render json: Health::Report.metrics, status: :ok
  end
end
