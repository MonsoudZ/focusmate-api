# frozen_string_literal: true

class DailySummary < ApplicationRecord
  belongs_to :coaching_relationship

  # Treat JSON column as a Hash by default
  attribute :summary_data, :json, default: {}

  # Soft delete: exclude deleted rows by default
  default_scope { where(deleted_at: nil) }

  # Validations
  validates :summary_date, presence: true
  validates :summary_date, uniqueness: { scope: :coaching_relationship_id }
  validates :tasks_completed, :tasks_missed, :tasks_overdue, presence: true
  validates :tasks_completed, :tasks_missed, :tasks_overdue,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :summary_data_must_be_object
  validate :summary_date_cannot_be_in_future
  validate :coaching_relationship_must_be_active

  # Callbacks
  before_validation :apply_defaults

  # Scopes
  scope :sent, -> { where(sent: true) }
  scope :unsent, -> { where(sent: false) }
  scope :for_date, ->(date) { where(summary_date: date.to_date) }
  scope :for_coaching_relationship, ->(rel) { where(coaching_relationship_id: rel.is_a?(CoachingRelationship) ? rel.id : rel) }
  scope :recent, -> { where("summary_date > ?", 7.days.ago.to_date).order(summary_date: :desc) }
  scope :with_tasks, -> { where("tasks_completed > 0 OR tasks_missed > 0 OR tasks_overdue > 0") }

  # Instance helpers
  def mark_sent!
    update!(sent: true, sent_at: Time.current)
  end

  def payload
    DailySummaryCalculator.new(user: coaching_relationship.client, date: summary_date).call
  end

  # Soft deletion API expected by specs
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Unscoped helper for specs that need to see deleted rows
  def self.with_deleted
    unscoped.all
  end

  # Class helpers (statistics) – key names aligned with spec
  class << self
    def statistics_for_coaching_relationship(rel)
      rel_id = rel.is_a?(CoachingRelationship) ? rel.id : rel
      rows = unscoped.where(coaching_relationship_id: rel_id, deleted_at: nil)

      totals_completed = rows.sum(:tasks_completed)
      totals_missed    = rows.sum(:tasks_missed)
      totals_overdue   = rows.sum(:tasks_overdue)
      average_rate     = begin
        total_tasks = totals_completed + totals_missed
        total_tasks.zero? ? 0.0 : ((totals_completed.to_f / total_tasks) * 100).round(2)
      end

      {
        total_summaries: rows.count,
        total_tasks_completed: totals_completed,
        total_tasks_missed: totals_missed,
        total_tasks_overdue: totals_overdue,
        average_completion_rate: average_rate
      }
    end
  end

  private

  # Only default when *all* three counters are missing (so "presence" specs still fail correctly).
  def apply_defaults
    return unless tasks_completed.nil? && tasks_missed.nil? && tasks_overdue.nil?
    self.tasks_completed = 0
    self.tasks_missed    = 0
    self.tasks_overdue   = 0
    self.summary_data  ||= {}
  end

  # Only allow JSON objects (Hash) for this column and surface the exact message expected.
  def summary_data_must_be_object
    return if summary_data.nil?
    errors.add(:summary_data, "is not a valid JSON") unless summary_data.is_a?(Hash)
  end

  def summary_date_cannot_be_in_future
    return if summary_date.blank?
    errors.add(:summary_date, "cannot be in the future") if summary_date.to_date > Date.current
  end

  def coaching_relationship_must_be_active
    return if coaching_relationship.blank?
    is_active =
      if coaching_relationship.respond_to?(:active?)
        coaching_relationship.active?
      else
        coaching_relationship.respond_to?(:status) ? coaching_relationship.status.to_s == "active" : true
      end
    errors.add(:coaching_relationship, "must be active") unless is_active
  end
end
