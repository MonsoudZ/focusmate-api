class DailySummary < ApplicationRecord
  belongs_to :coaching_relationship

  validates :summary_date, presence: true
  validates :coaching_relationship_id, uniqueness: { scope: :summary_date }
  validates :tasks_completed, :tasks_missed, :tasks_overdue,
            numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :sent, -> { where(sent: true) }
  scope :unsent, -> { where(sent: false) }
  scope :for_date, ->(date) { where(summary_date: date) }
  scope :recent, -> { order(summary_date: :desc) }

  # Check if summary was sent
  def sent?
    sent
  end

  # Mark as sent
  def mark_sent!
    update!(sent: true, sent_at: Time.current)
  end

  # Get completion rate
  def completion_rate
    total_tasks = tasks_completed + tasks_missed
    return 0 if total_tasks.zero?
    (tasks_completed.to_f / total_tasks * 100).round(2)
  end

  # Get summary data
  def summary_data
    super || {}
  end

  # Set summary data
  def summary_data=(value)
    super(value.to_json) if value.present?
  end

  # Get parsed summary data
  def parsed_summary_data
    return {} if summary_data.blank?
    JSON.parse(summary_data) rescue {}
  end

  # Get total tasks
  def total_tasks
    tasks_completed + tasks_missed
  end

  # Check if there are overdue tasks
  def has_overdue_tasks?
    tasks_overdue > 0
  end

  # Get performance grade
  def performance_grade
    case completion_rate
    when 90..100 then "A"
    when 80..89 then "B"
    when 70..79 then "C"
    when 60..69 then "D"
    else "F"
    end
  end
end
