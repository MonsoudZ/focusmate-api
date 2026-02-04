# frozen_string_literal: true

class HealthController < ActionController::API
  before_action :authenticate_diagnostics!, only: %i[detailed metrics]

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

  private

  def authenticate_diagnostics!
    return unless Rails.env.production?

    expected_token = ENV["HEALTH_DIAGNOSTICS_TOKEN"].to_s
    return head :not_found if expected_token.blank?

    provided_token = request.headers["X-Health-Token"].to_s
    return if token_match?(provided_token, expected_token)

    head :unauthorized
  end

  def token_match?(provided_token, expected_token)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(provided_token),
      Digest::SHA256.hexdigest(expected_token)
    )
  end
end
