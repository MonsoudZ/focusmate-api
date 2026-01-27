# frozen_string_literal: true

class AnalyticsEvent < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :list, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true

  # Event types
  TASK_EVENTS = %w[
    task_created
    task_completed
    task_reopened
    task_deleted
    task_snoozed
    task_starred
    task_unstarred
    task_priority_changed
    task_edited
  ].freeze

  LIST_EVENTS = %w[
    list_created
    list_deleted
    list_shared
  ].freeze

  USER_EVENTS = %w[
    app_opened
    session_started
  ].freeze

  ALL_EVENTS = (TASK_EVENTS + LIST_EVENTS + USER_EVENTS).freeze

  validates :event_type, inclusion: { in: ALL_EVENTS }

  scope :for_user, ->(user) { where(user: user) }
  scope :of_type, ->(type) { where(event_type: type) }
  scope :between, ->(start_time, end_time) { where(occurred_at: start_time..end_time) }
  scope :today, -> { where(occurred_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(occurred_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :this_month, -> { where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month) }
end
