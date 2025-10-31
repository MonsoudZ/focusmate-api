# frozen_string_literal: true

module TaskControllerShared
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :set_task
  end

  private

  def set_task
    @task = Task.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "Task not found: User #{current_user.id} tried to access task #{params[:id]}"
    render json: { error: { message: "Task not found" } }, status: :not_found
  end

  def parse_iso(date_string)
    return nil if date_string.blank?
    Time.parse(date_string)
  rescue ArgumentError
    nil
  end
end
