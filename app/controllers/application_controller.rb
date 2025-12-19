# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Api::ErrorHandling

  before_action :force_json_format
  before_action :authenticate_user!

  private

  def force_json_format
    request.format = :json
  end
end
