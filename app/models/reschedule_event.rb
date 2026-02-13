# frozen_string_literal: true

class RescheduleEvent < ApplicationRecord
  belongs_to :task
  belongs_to :user, optional: true

  PREDEFINED_REASONS = %w[
    scope_changed
    priorities_shifted
    blocked
    underestimated
    unexpected_work
    not_ready
  ].freeze

  validates :reason, presence: true
  validates :new_due_at, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
