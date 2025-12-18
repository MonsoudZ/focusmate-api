# frozen_string_literal: true

class HealthController < ActionController::API
  # Health endpoints should be public and resilient
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :force_json_format, raise: false

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
