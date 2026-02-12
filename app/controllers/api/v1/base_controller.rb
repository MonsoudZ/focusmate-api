# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Devise::Controllers::Helpers

      after_action :verify_authorized
    end
  end
end
