# frozen_string_literal: true

module DeviseApiHelpers
  extend ActiveSupport::Concern

  included do
    include Devise::Controllers::Helpers
  end
end
