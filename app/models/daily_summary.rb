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

  # Additional production scopes
  scope :for_date_range, ->(start_date, end_date) { where(summary_date: start_date.to_date..end_date.to_date) }
  scope :this_week, -> { where(summary_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(summary_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :last_week, -> { where(summary_date: 1.week.ago.beginning_of_week..1.week.ago.end_of_week) }
  scope :last_month, -> { where(summary_date: 1.month.ago.beginning_of_month..1.month.ago.end_of_month) }
  scope :high_performance, -> { where("tasks_completed > tasks_missed + tasks_overdue") }
  scope :needs_attention, -> { where("tasks_missed > 0 OR tasks_overdue > 0") }
  scope :by_completion_rate, ->(min_rate) {
    where("tasks_completed::float / NULLIF(tasks_completed + tasks_missed, 0) >= ?", min_rate / 100.0)
  }

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

  # Performance metrics
  def completion_rate
    total_tasks = tasks_completed + tasks_missed
    return 0.0 if total_tasks.zero?
    (tasks_completed.to_f / total_tasks * 100).round(2)
  end

  def total_tasks
    tasks_completed + tasks_missed + tasks_overdue
  end

  def has_tasks?
    total_tasks > 0
  end

  def performance_grade
    case completion_rate
    when 90..100 then "A"
    when 80..89  then "B"
    when 70..79  then "C"
    when 60..69  then "D"
    else "F"
    end
  end

  def needs_attention?
    tasks_missed > 0 || tasks_overdue > 0
  end

  def high_performance?
    tasks_completed > (tasks_missed + tasks_overdue)
  end

  # Data access helpers
  def summary_data_for(key)
    summary_data&.dig(key.to_s)
  end

  def update_summary_data!(data)
    update!(summary_data: summary_data.merge(data.stringify_keys))
  end

  # Date helpers
  def day_of_week
    summary_date.strftime("%A")
  end

  def formatted_date
    summary_date.strftime("%B %d, %Y")
  end

  def is_today?
    summary_date == Date.current
  end

  def is_this_week?
    summary_date >= Date.current.beginning_of_week && summary_date <= Date.current.end_of_week
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

    # Additional analytics methods
    def performance_trends_for_coaching_relationship(rel, days = 30)
      rel_id = rel.is_a?(CoachingRelationship) ? rel.id : rel
      summaries = unscoped
                    .where(coaching_relationship_id: rel_id, deleted_at: nil)
                    .where("summary_date >= ?", days.days.ago.to_date)
                    .order(:summary_date)

      {
        daily_completion_rates: summaries.map(&:completion_rate),
        daily_totals: summaries.map { |s| { date: s.summary_date, total: s.total_tasks } },
        weekly_averages: calculate_weekly_averages(summaries),
        performance_grade_distribution: calculate_grade_distribution(summaries)
      }
    end

    def find_or_create_for_date(rel, date)
      rel_id = rel.is_a?(CoachingRelationship) ? rel.id : rel
      find_by(coaching_relationship_id: rel_id, summary_date: date.to_date) ||
        create!(coaching_relationship_id: rel_id, summary_date: date.to_date)
    end

    def bulk_create_for_date_range(rel, start_date, end_date)
      rel_id = rel.is_a?(CoachingRelationship) ? rel.id : rel
      dates = (start_date.to_date..end_date.to_date).to_a
      existing_dates = where(coaching_relationship_id: rel_id, summary_date: dates).pluck(:summary_date)
      new_dates = dates - existing_dates

      new_dates.map do |date|
        create!(coaching_relationship_id: rel_id, summary_date: date)
      end
    end

    def export_data_for_coaching_relationship(rel, format = :csv)
      rel_id = rel.is_a?(CoachingRelationship) ? rel.id : rel
      summaries = unscoped.where(coaching_relationship_id: rel_id, deleted_at: nil).order(:summary_date)

      case format
      when :csv
        export_to_csv(summaries)
      when :json
        export_to_json(summaries)
      else
        summaries
      end
    end

    private

    def calculate_weekly_averages(summaries)
      summaries.group_by { |s| s.summary_date.beginning_of_week }
               .transform_values { |week_summaries|
                 week_summaries.map(&:completion_rate).sum / week_summaries.size
               }
    end

    def calculate_grade_distribution(summaries)
      grades = summaries.map(&:performance_grade)
      grades.tally
    end

    def export_to_csv(summaries)
      require "csv"
      CSV.generate do |csv|
        csv << %w[Date Tasks_Completed Tasks_Missed Tasks_Overdue Completion_Rate Performance_Grade]
        summaries.each do |summary|
          csv << [
            summary.summary_date,
            summary.tasks_completed,
            summary.tasks_missed,
            summary.tasks_overdue,
            summary.completion_rate,
            summary.performance_grade
          ]
        end
      end
    end

    def export_to_json(summaries)
      summaries.map do |summary|
        {
          date: summary.summary_date,
          tasks_completed: summary.tasks_completed,
          tasks_missed: summary.tasks_missed,
          tasks_overdue: summary.tasks_overdue,
          completion_rate: summary.completion_rate,
          performance_grade: summary.performance_grade,
          summary_data: summary.summary_data
        }
      end
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
