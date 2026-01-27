# frozen_string_literal: true

class Task < ApplicationRecord
  include SoftDeletable

  belongs_to :list, counter_cache: true
  belongs_to :creator, class_name: "User", foreign_key: :creator_id
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :parent_task, class_name: "Task", optional: true, counter_cache: :subtasks_count
  belongs_to :template, class_name: "Task", optional: true
  has_many :instances, class_name: "Task", foreign_key: :template_id, dependent: :destroy

  has_many :subtasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :destroy
  has_many :task_events, dependent: :destroy
  has_many :task_tags, dependent: :destroy
  has_many :tags, through: :task_tags

  # Enums
  enum :status, { pending: 0, in_progress: 1, done: 2 }, default: :pending
  enum :visibility, { visible_to_all: 0, private_task: 1 }, default: :visible_to_all
  enum :priority, { no_priority: 0, low: 1, medium: 2, high: 3, urgent: 4 }, default: :no_priority
  COLORS = %w[blue green orange red purple pink teal yellow gray].freeze

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }, allow_nil: true
  validates :due_at, presence: true, unless: :subtask?
  validates :strict_mode, inclusion: { in: [ true, false ] }
  validates :notification_interval_minutes, numericality: { greater_than: 0 }, allow_nil: true
  validates :recurrence_pattern, inclusion: { in: %w[daily weekly monthly yearly] }, allow_nil: true
  validates :recurrence_interval, numericality: { greater_than: 0 }, allow_nil: true

  validate :due_at_not_in_past_on_create
  validate :prevent_circular_subtask_relationship
  validate :recurrence_constraints
  validate :assigned_to_has_list_access
  validates :color, inclusion: { in: COLORS }, allow_nil: true

  after_initialize :set_defaults
  after_create :record_creation_event
  after_update :handle_status_change_callbacks, if: :saved_change_to_status?
  after_update :adjust_list_counter_on_soft_delete, if: :saved_change_to_deleted_at?
  after_update :adjust_parent_subtasks_counter_on_soft_delete, if: :saved_change_to_deleted_at?
  accepts_nested_attributes_for :task_tags, allow_destroy: true

  # Scopes (SoftDeletable provides: with_deleted, only_deleted, not_deleted)
  scope :completed, -> { where(status: :done) }
  scope :pending, -> { where(status: :pending) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :overdue, -> { pending.where("due_at < ?", Time.current) }
  scope :due_soon, -> { where("due_at <= ?", 1.day.from_now) }
  scope :incomplete, -> { where.not(status: :done) }
  scope :recurring, -> { where(is_recurring: true) }
  scope :by_list, ->(list_id) { where(list_id: list_id) }
  scope :by_creator, ->(creator_id) { where(creator_id: creator_id) }

  # Primary sorting scope - urgent tasks first, then starred, then by position/column
  scope :sorted_with_priority, ->(column = :created_at, direction = :desc) {
    order(
      Arel.sql("CASE WHEN priority = 4 THEN 0 WHEN starred = true THEN 1 ELSE 2 END"),
      Arel.sql("COALESCE(position, 999999)"),
      column => direction
    )
  }

  scope :visible, -> { where(is_template: [ false, nil ]) }
  scope :templates, -> { where(is_template: true) }
  scope :recurring_templates, -> { where(is_template: true, template_type: "recurring") }

  # Business logic
  def complete!
    update!(status: :done, completed_at: Time.current)
  end

  def uncomplete!
    update!(status: :pending, completed_at: nil)
  end

  def snooze!(duration)
    raise ArgumentError, "duration required" if duration.blank?
    update!(due_at: (due_at || Time.current) + duration)
  end

  def overdue?
    pending? && due_at.present? && due_at < Time.current
  end

  def done?
    status == "done"
  end

  def editable_by?(user)
    user.present? && list.can_edit?(user)
  end

  def visible_to?(user)
    return false unless user
    return false if list.deleted?
    list.accessible_by?(user)
  end

  # Recurrence
  def calculate_next_due_date
    return nil unless is_recurring?
    TaskRecurrenceService.new(self).calculate_next_due_date
  end

  def generate_next_instance
    TaskRecurrenceService.new(self).generate_next_instance
  end

  def subtask?
    parent_task_id.present?
  end

  private

  def set_defaults
    self.strict_mode = false if strict_mode.nil?
  end

  def record_creation_event
    TaskEventRecorder.new(self).record_creation
  end

  def handle_status_change_callbacks
    recorder = TaskEventRecorder.new(self)
    recorder.record_status_change
    recorder.check_parent_completion
  end

  def due_at_not_in_past_on_create
    return unless new_record?
    return unless due_at.present?
    return if Rails.env.test?

    # Allow any time today, but not past days
    if due_at < Time.current.beginning_of_day
      errors.add(:due_at, "cannot be in the past")
    end
  end

  def prevent_circular_subtask_relationship
    return unless parent_task_id.present?
    if parent_task_id == id
      errors.add(:parent_task, "cannot be self")
      return
    end
    current = parent_task
    while current
      if current.id == id
        errors.add(:parent_task, "would create a circular relationship")
        break
      end
      current = current.parent_task
    end
  end

  def recurrence_constraints
    return if recurrence_pattern.blank?

    if recurrence_pattern == "weekly" && recurrence_days.blank?
      errors.add(:recurrence_days, "is required for weekly recurring tasks")
    end
  end

  def assigned_to_has_list_access
    return unless assigned_to_id.present?
    return unless list.present?

    assignee = User.find_by(id: assigned_to_id)
    unless assignee && list.accessible_by?(assignee)
      errors.add(:assigned_to, "does not have access to this list")
    end
  end

  def adjust_list_counter_on_soft_delete
    if deleted_at.present?
      # Task was soft deleted - decrement counter
      List.decrement_counter(:tasks_count, list_id)
    else
      # Task was restored - increment counter
      List.increment_counter(:tasks_count, list_id)
    end
  end

  def adjust_parent_subtasks_counter_on_soft_delete
    return unless parent_task_id.present?

    if deleted_at.present?
      Task.decrement_counter(:subtasks_count, parent_task_id)
    else
      Task.increment_counter(:subtasks_count, parent_task_id)
    end
  end


end
