class CoachingRelationship < ApplicationRecord
  # Define status attribute accessor that doesn't raise on invalid values
  attribute :status, :string, default: "pending"

  # Override status setter to catch invalid enum values
  def status=(value)
    super(value)
  rescue ArgumentError
    @invalid_status = value
    super(nil)
  end

  enum :status, { pending: "pending", active: "active", inactive: "inactive", declined: "declined" }

  belongs_to :coach, class_name: "User"
  belongs_to :client, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships
  has_many :daily_summaries, dependent: :destroy
  has_many :item_visibility_restrictions, dependent: :destroy

  validates :coach_id, :client_id, presence: true
  validates :status, presence: true
  validates :invited_by, presence: true
  validates :coach_id, uniqueness: { scope: :client_id }
  validate :coach_and_client_different
  validate :status_is_valid

  scope :between, ->(coach_id:, client_id:) { where(coach_id:, client_id:) }

  # Scopes for status filtering
  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :inactive, -> { where(status: "inactive") }
  scope :declined, -> { where(status: "declined") }
  scope :for_user, ->(user_id) { where("coach_id = ? OR client_id = ?", user_id, user_id) }
  scope :for_coach, ->(coach) { where(coach_id: coach.id) }
  scope :for_client, ->(client) { where(client_id: client.id) }

  # Instance methods
  def active?
    status == "active"
  end

  def pending?
    status == "pending"
  end

  def inactive?
    status == "inactive"
  end

  def declined?
    status == "declined"
  end

  def activate!
    update!(status: "active", accepted_at: Time.current)
  end

  def accept!
    update!(status: "active", accepted_at: Time.current)
  end

  def deactivate!
    update!(status: "inactive")
  end

  def decline!
    update!(status: "declined")
  end

  def user_role(user)
    return "coach" if coach_id == user.id
    return "client" if client_id == user.id
    nil
  end

  def other_user(user)
    return coach if client_id == user.id
    return client if coach_id == user.id
    nil
  end

  def can_be_accessed_by?(user)
    coach_id == user.id || client_id == user.id
  end

  def can_be_modified_by?(user)
    # Only coach can modify the relationship
    coach_id == user.id
  end

  def display_name_for(user)
    other_user = other_user(user)
    return "Unknown" unless other_user

    other_user.name.presence || other_user.email
  end

  # Daily summary methods
  def create_daily_summary!(date)
    daily_summaries.create!(
      summary_date: date,
      tasks_completed: 0,
      tasks_missed: 0
    )
  end

  def should_send_daily_summary?
    send_daily_summary && daily_summary_time.present?
  end

  def daily_summary_for(date)
    daily_summaries.find_by(summary_date: date)
  end

  def recent_summaries(days)
    daily_summaries.where("summary_date >= ?", days.days.ago).order(summary_date: :desc).limit(days)
  end

  def average_completion_rate(days)
    summaries = daily_summaries.where("summary_date >= ?", days.days.ago)
    return 0 if summaries.empty?

    total_completed = summaries.sum(:tasks_completed)
    total_missed = summaries.sum(:tasks_missed)
    total_tasks = total_completed + total_missed

    return 0 if total_tasks.zero?

    (total_completed.to_f / total_tasks * 100).round(1)
  end

  def performance_trend(days)
    summaries = daily_summaries.where("summary_date >= ?", days.days.ago).order(summary_date: :asc)
    return "stable" if summaries.count < 2

    # Calculate completion rates for first and second half
    half = summaries.count / 2
    first_half = summaries.limit(half)
    second_half = summaries.offset(half)

    first_half_rate = calculate_completion_rate(first_half)
    second_half_rate = calculate_completion_rate(second_half)

    if second_half_rate > first_half_rate + 5
      "improving"
    elsif second_half_rate < first_half_rate - 5
      "declining"
    else
      "stable"
    end
  end

  # Task management methods
  def all_tasks
    Task.joins(list: :memberships)
        .where(memberships: { coaching_relationship_id: id })
        .distinct
  end

  def overdue_tasks
    all_tasks.where("due_at < ? AND status NOT IN (?)", Time.current, [Task.statuses[:done], Task.statuses[:deleted]])
  end

  # Class methods
  class << self
    def find_between(coach_id:, client_id:)
      between(coach_id: coach_id, client_id: client_id).first
    end

    def find_or_create_between(coach_id:, client_id:, status: "pending")
      find_between(coach_id: coach_id, client_id: client_id) ||
        create!(coach_id: coach_id, client_id: client_id, status: status)
    end

    def active_for_user(user_id)
      for_user(user_id).active
    end

    def pending_for_user(user_id)
      for_user(user_id).pending
    end

    def count_by_status
      group(:status).count
    end

    def recent(limit = 10)
      order(created_at: :desc).limit(limit)
    end
  end

  private

  def coach_and_client_different
    errors.add(:client_id, "cannot be the same as coach") if coach_id == client_id
  end

  def status_is_valid
    # Check if an invalid status was attempted to be set
    if @invalid_status.present?
      errors.add(:status, "is not included in the list")
    end
  end

  def calculate_completion_rate(summaries)
    return 0 if summaries.empty?

    total_completed = summaries.sum(:tasks_completed)
    total_missed = summaries.sum(:tasks_missed)
    total_tasks = total_completed + total_missed

    return 0 if total_tasks.zero?

    (total_completed.to_f / total_tasks * 100).round(1)
  end
end
