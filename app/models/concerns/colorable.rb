# frozen_string_literal: true

module Colorable
  extend ActiveSupport::Concern

  COLORS = %w[blue green orange red purple pink teal yellow gray].freeze

  included do
    validates :color, inclusion: { in: COLORS }, allow_nil: true
  end
end
