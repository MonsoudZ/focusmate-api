class Task < ApplicationRecord
  belongs_to :list
  belongs_to :creator, class_name: "User", foreign_key: :creator_id
  has_many :task_events, dependent: :destroy

  # NEW associations for coaching features
  belongs_to :parent_task, class_name: "Task", optional: true
  belongs_to :recurring_template, class_name: "Task", optional: true
  has_many :subtasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :destroy
  has_many :recurring_instances, class_name: "Task", foreign_key: :recurring_template_id, dependent: :destroy
  has_many :visibility_restrictions, class_name: "ItemVisibilityRestriction",
           foreign_key: :task_id, dependent: :destroy
  has_one :escalation, class_name: "ItemEscalation", foreign_key: :task_id, dependent: :destroy
  has_many :notification_logs, foreign_key: :task_id, dependent: :destroy
  belongs_to :missed_reason_reviewed_by, class_name: "User", optional: true

  # Enums
  enum :status, { pending: 0, in_progress: 1, done: 2, deleted: 3 }, default: :pending
  enum :visibility, { visible_to_all: 0, hidden_from_coaches: 1, private_task: 2, coaching_only: 3 }

  # Callbacks
  after_update :track_status_changes
  after_update :track_completion
  after_update :check_parent_completion, if: :saved_change_to_status?

  # Validations
  validates :title, presence: true, length: { maximum: 1000 }
  validates :note, length: { maximum: 1000 }
  validates :due_at, presence: true
  validates :strict_mode, inclusion: { in: [ true, false ] }
  validates :recurrence_pattern, inclusion: { in: %w[daily weekly monthly yearly] }, allow_nil: true
  validates :recurrence_interval, numericality: { greater_than: 0 }, allow_nil: true
  validates :location_radius_meters, numericality: { in: 10..10000 }, if: :location_based?
  validates :location_latitude, :location_longitude, presence: { message: 'are required for location-based tasks' }, if: :location_based
  validates :notification_interval_minutes, numericality: { greater_than: 0 }
  
  # Custom validations
  validate :due_at_not_in_past_on_create
  validate :prevent_circular_subtask_relationship
  validate :subtask_due_date_not_after_parent
  validate :recurrence_pattern_requirements
  validate :location_requirements

  # Scopes
  scope :active, -> { where.not(status: :deleted) }
  scope :completed, -> { where(status: :done) }
  scope :pending, -> { where(status: :pending) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :modified_since, ->(timestamp) { where("tasks.updated_at > ? OR tasks.deleted_at > ?", timestamp, timestamp) }
  scope :due_soon, -> { where("due_at <= ?", 1.day.from_now) }
  scope :overdue, -> { where(status: [:pending, :in_progress]).where("due_at < ?", Time.current) }
  scope :awaiting_explanation, -> { where(requires_explanation_if_missed: true, status: :pending).where("due_at < ?", Time.current) }
  scope :templates, -> { where(is_recurring: true, recurring_template_id: nil) }
  scope :instances, -> { where.not(recurring_template_id: nil) }
  scope :incomplete, -> { where.not(status: :done) }
  scope :location_based, -> { where(location_based: true) }
  scope :recurring, -> { where(is_recurring: true) }
  scope :by_list, ->(list_id) { where(list_id: list_id) }
  scope :by_creator, ->(creator_id) { where(creator_id: creator_id) }
  scope :snoozable, -> { where(can_be_snoozed: true) }
  scope :strict_mode, -> { where(strict_mode: true) }

  # Visibility scopes
  scope :visible_tasks, -> { where(visibility: :visible) }
  scope :hidden_tasks, -> { where(visibility: :hidden) }
  scope :coaching_only_tasks, -> { where(visibility: :coaching_only) }
  scope :visible_to_user, ->(user) {
    if user.coach?
      where(visibility: [ :visible, :coaching_only ])
    else
      where(visibility: :visible)
    end
  }

  # Callbacks
  after_create :create_task_event
  after_update :create_status_change_event, if: :saved_change_to_status?
  after_commit :broadcast_create, on: :create
  after_commit :broadcast_update, on: :update
  before_destroy :broadcast_delete

  # Business logic methods
  def complete!
    update!(
      status: 1,
      completed_at: Time.current
    )

    # Clear escalation if exists
    escalation&.update!(
      escalation_level: "normal",
      notification_count: 0,
      blocking_app: false,
      blocking_started_at: nil
    ) if escalation
  end

  def uncomplete!
    update!(
      status: 0,
      completed_at: nil
    )
  end

  def reassign!(user, new_due_at:, reason:)
    return false if strict_mode && reason.blank?
    return false if new_due_at.blank?

    old_due_at = due_at
    self.due_at = new_due_at
    save!
    create_task_event(
      user: user,
      kind: :reassigned,
      reason: reason,
      occurred_at: Time.current
    )
    true
  end

  def soft_delete!(user, reason: nil)
    return false if deleted?

    self.status = :deleted
    self.deleted_at = Time.current
    save!
    create_task_event(user: user, kind: :deleted, reason: reason)
    true
  end

  def deleted?
    deleted_at.present?
  end

  def restore!
    update!(deleted_at: nil, status: :pending)
  end

  def can_be_reassigned_by?(user)
    return false unless list.can_edit?(user)
    return false if strict_mode && due_at.present? && due_at > Time.current
    true
  end

  # Get reassignment history for coaches
  def reassignment_history
    task_events.reassigned.includes(:user).map do |event|
      {
        user: event.user.email,
        reason: event.reason,
        occurred_at: event.occurred_at,
        old_due_at: event.occurred_at - 1.day, # This would need to be stored properly in real implementation
        new_due_at: due_at
      }
    end
  end

  # Get completion rate for analytics
  def self.completion_rate_for_user(user, date_range = nil)
    scope = joins(:list).where(list: List.accessible_by(user))
    scope = scope.where(created_at: date_range) if date_range

    total = scope.count
    completed = scope.where(status: :done).count

    return 0 if total.zero?
    (completed.to_f / total * 100).round(2)
  end

  # NEW: Coaching-related methods

  # Check if task is overdue
  def overdue?
    pending? && due_at.present? && due_at < Time.current
  end

  # Get minutes overdue
  def minutes_overdue
    return 0 unless overdue?
    ((Time.current - due_at) / 1.minute).round
  end

  # Check if task requires explanation
  def requires_explanation?
    requires_explanation_if_missed && overdue? && missed_reason.blank?
  end

  # Check if task was created by a coach
  def created_by_coach?
    creator&.coach?
  end

  # Check if task is editable by user
  def editable_by?(user)
    return false unless user
    list.can_edit?(user)
  end

  # Check if task is deletable by user
  def deletable_by?(user)
    return false unless user
    list.can_edit?(user)
  end

  # Check if task is completable by user
  def completable_by?(user)
    return false unless user
    return false if done? || deleted?
    list.can_edit?(user)
  end

  # Get subtask completion percentage
  def subtask_completion_percentage
    return 0 if subtasks.empty?
    (subtasks.where(status: :done).count.to_f / subtasks.count * 100).round(1)
  end

  # Check if task should block the app
  def should_block_app?
    return false unless overdue?
    return false if can_be_snoozed?

    # Block app based on time overdue (simplified without priority)
    minutes_overdue > 120 # 2 hours
  end

  # Create escalation record if it doesn't exist
  def create_escalation!
    return escalation if escalation.present?

    ItemEscalation.create!(
      task: self,
      escalation_level: "normal",
      notification_count: 0,
      became_overdue_at: Time.current
    )
  end

  # Check if all subtasks are completed
  def all_subtasks_completed?
    return true if subtasks.empty?
    subtasks.all?(&:done?)
  end

  def done?
    status == "done"
  end

  # Schedule completion handler when task is completed
  after_commit :schedule_completion_handler, on: :update, if: :saved_change_to_status?

  # Check location trigger for location-based tasks
  after_commit :check_location_trigger, on: :create, if: :location_based?

  def can_change_visibility?(user)
    return false unless user
    # Only creator, list owner, or coaches can change visibility
    creator == user || list.owner == user || (user.coach? && list.coach?(user))
  end

  def make_visible!
    update!(visibility: :visible)
  end

  def make_hidden!
    update!(visibility: :hidden)
  end

  def make_coaching_only!
    update!(visibility: :coaching_only)
  end

  # Check if task is location-based
  def location_based?
    !!self[:location_based] && location_latitude.present? && location_longitude.present?
  end

  # Get location coordinates
  def coordinates
    return nil unless location_based?
    [ location_latitude, location_longitude ]
  end

  # Check if user is at task location
  def user_at_location?(user_latitude, user_longitude)
    return false unless location_based?
    return false if user_latitude.blank? || user_longitude.blank?

    distance = calculate_distance(
      location_latitude, location_longitude,
      user_latitude, user_longitude
    )
    distance <= location_radius_meters
  end

  # Visibility control methods
  def visible_to?(user)
    return false unless user
    
    # Check if list is deleted - users cannot see tasks in deleted lists
    if list.deleted?
      return false
    end
    
    # Check if task is deleted - only owner can see deleted tasks
    if deleted?
      return creator == user || list.owner == user
    end

    case visibility
    when "visible_to_all"
      true
    when "hidden_from_coaches"
      # Only visible to task creator and list owner
      creator == user || list.owner == user
    when "private_task"
      # Only visible to task creator and list owner
      creator == user || list.owner == user
    else
      false
    end
  end

  # Recurring template methods
  def is_recurring?
    !!self[:is_recurring]
  end

  # Generate next instance of recurring template
  def generate_next_instance
    return nil unless is_template?
    return nil if recurrence_end_date.present? && recurrence_end_date < Time.current

    # Calculate next due date based on recurrence pattern
    next_due_at = case recurrence_pattern
    when "daily"
      calculate_daily_recurrence
    when "weekly"
      calculate_weekly_recurrence
    when "monthly"
      calculate_monthly_recurrence
    else
      nil
    end

    return nil unless next_due_at

    # Create new instance
    instance = list.tasks.build(
      title: title,
      note: note,
      due_at: next_due_at,
      strict_mode: strict_mode,
      can_be_snoozed: can_be_snoozed,
      notification_interval_minutes: notification_interval_minutes,
      requires_explanation_if_missed: requires_explanation_if_missed,
      location_based: location_based,
      location_latitude: location_latitude,
      location_longitude: location_longitude,
      location_radius_meters: location_radius_meters,
      location_name: location_name,
      notify_on_arrival: notify_on_arrival,
      notify_on_departure: notify_on_departure,
      is_recurring: false,
      recurring_template_id: id,
      creator: creator,
      status: :pending
    )

    instance.save ? instance : nil
  end

  def is_template?
    is_recurring? && recurring_template_id.nil?
  end

  def is_instance?
    recurring_template_id.present?
  end

  # Create next occurrence for recurring tasks
  def create_next_occurrence!
    return nil unless is_recurring?
    
    next_due_at = calculate_next_due_date
    return nil unless next_due_at
    
    Task.create!(
      title: title,
      note: note,
      due_at: next_due_at,
      strict_mode: strict_mode,
      can_be_snoozed: can_be_snoozed,
      notification_interval_minutes: notification_interval_minutes,
      requires_explanation_if_missed: requires_explanation_if_missed,
      visibility: visibility,
      list: list,
      creator: creator,
      parent_task: self,
      is_recurring: false
    )
  end

  # Soft delete with proper scoping
  def soft_delete!(user, reason: nil)
    return false if deleted?
    
    self.status = :deleted
    self.deleted_at = Time.current
    save!
    create_task_event(user: user, kind: :deleted, reason: reason)
    true
  end

  # Permanently delete
  def destroy!
    super
  end

  # Check if user is within geofence
  def user_within_geofence?(user)
    return false unless location_based? && user.current_location
    
    # Calculate distance using Haversine formula
    lat1 = user.current_latitude.to_f
    lon1 = user.current_longitude.to_f
    lat2 = location_latitude.to_f
    lon2 = location_longitude.to_f
    
    return false if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
    
    # Haversine formula for distance calculation
    dlat = (lat2 - lat1) * Math::PI / 180
    dlon = (lon2 - lon1) * Math::PI / 180
    a = Math.sin(dlat/2) * Math.sin(dlat/2) + Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(dlon/2) * Math.sin(dlon/2)
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    distance = 6371000 * c # Earth's radius in meters
    
    distance <= location_radius_meters
  end

  # Complete parent when all subtasks are done
  def check_parent_completion
    return unless parent_task && parent_task.subtasks.pending.empty?
    
    parent_task.update!(status: :done) if parent_task.status == 'pending'
  end

  # Submit missed reason
  def submit_missed_reason!(reason, user)
    return false unless requires_explanation_if_missed? && overdue?
    
    update!(
      missed_reason: reason,
      missed_reason_submitted_at: Time.current,
      missed_reason_reviewed_by: user
    )
    true
  end

  # Review missed reason (coach only)
  def review_missed_reason!(coach, approved: true)
    return false unless coach.coach? && missed_reason.present?
    
    update!(
      missed_reason_reviewed_by: coach,
      missed_reason_reviewed_at: Time.current
    )
    true
  end

  # Check if task can be reassigned
  def can_be_reassigned_by?(user)
    return false unless list.can_edit?(user)
    return false if strict_mode && due_at.present? && due_at > Time.current
    true
  end

  # Reassign task
  def reassign!(user, new_due_at:, reason:)
    return false if strict_mode && reason.blank?
    return false if new_due_at.blank?
    return false unless can_be_reassigned_by?(user)

    old_due_at = due_at
    self.due_at = new_due_at
    save!
    create_task_event(
      user: user,
      kind: :reassigned,
      reason: reason,
      occurred_at: Time.current
    )
    true
  end

  # Submit missed reason
  def submit_missed_reason!(reason, user)
    return false unless requires_explanation_if_missed? && overdue?
    
    update!(
      missed_reason: reason,
      missed_reason_submitted_at: Time.current,
      missed_reason_reviewed_by: user
    )
    true
  end

  # Review missed reason (coach only)
  def review_missed_reason!(coach, approved: true)
    return false unless coach.coach? && missed_reason.present?
    
    update!(
      missed_reason_reviewed_by: coach,
      missed_reason_reviewed_at: Time.current
    )
    true
  end

  # Get all instances of this template
  def recurring_instances
    Task.where(recurring_template_id: id)
  end

  # Force public predicate helpers in case something made them private:
  def can_be_snoozed?
    !!self[:can_be_snoozed] && pending?
  end

  def requires_explanation_if_missed?
    !!self[:requires_explanation_if_missed]
  end

  def location_based?
    !!self[:location_based] && location_latitude.present? && location_longitude.present?
  end

  def is_recurring?
    !!self[:is_recurring]
  end

  # Get escalation level
  def escalation_level
    escalation&.escalation_level || "normal"
  end

  # Check if task is blocking the app
  def blocking_app?
    escalation&.blocking_app || false
  end

  # Get visibility for coaching relationship
  def visible_to_coaching_relationship?(coaching_relationship)
    return true unless visibility_restrictions.exists?
    visibility_restrictions.exists?(coaching_relationship: coaching_relationship)
  end

  private

  def schedule_completion_handler
    if done?
      TaskCompletionHandlerWorker.perform_async(id)
    end
  end

  def check_location_trigger
    # Optionally trigger immediate location check if task is location-based
    if list.owner.current_location.present?
      loc = list.owner.current_location
      LocationCheckWorker.perform_async(
        list.owner.id,
        loc.latitude,
        loc.longitude,
        loc.accuracy
      )
    end
  end

  # Check if task is recurring
  def recurring?
    is_recurring && recurring_template_id.present?
  end

  # Submit explanation (alias for submit_missed_reason!)
  def submit_explanation!(reason, user)
    submit_missed_reason!(reason, user)
  end

  # Show task to coaching relationship
  def show_to!(coaching_relationship)
    visibility_restrictions.find_or_create_by!(coaching_relationship: coaching_relationship)
  end

  # Hide task from coaching relationship
  def hide_from!(coaching_relationship)
    visibility_restrictions.find_by(coaching_relationship: coaching_relationship)&.destroy
  end


  private

  # Calculate distance between two coordinates using Haversine formula
  def calculate_distance(lat1, lon1, lat2, lon2)
    return 0 if lat1 == lat2 && lon1 == lon2

    # Convert to radians
    lat1_rad = lat1 * Math::PI / 180
    lon1_rad = lon1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    lon2_rad = lon2 * Math::PI / 180

    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    a = Math.sin(dlat/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon/2)**2
    c = 2 * Math.asin(Math.sqrt(a))

    # Earth's radius in meters
    6371000 * c
  end

  def create_task_event(user: nil, kind: :created, reason: nil, occurred_at: nil)
    task_events.create!(
      user: user || list.owner,
      kind: kind,
      reason: reason,
      occurred_at: occurred_at || Time.current
    )
  end

  def create_status_change_event
    kind = case status
    when "done"
      :completed
    when "pending"
      :created
    when "deleted"
      :deleted
    else
      :created
    end
    
    create_task_event(kind: kind)
  end

  def broadcast_create = Broadcasts.task_created(self)
  def broadcast_update = Broadcasts.task_updated(self)
  def broadcast_delete = Broadcasts.task_deleted(self)

  # Get next due date based on recurrence pattern
  def calculate_next_due_date
    return nil unless is_template?

    case recurrence_pattern
    when "daily"
      calculate_daily_recurrence
    when "weekly"
      calculate_weekly_recurrence
    when "monthly"
      calculate_monthly_recurrence
    when "yearly"
      calculate_yearly_recurrence
    else
      nil
    end
  end

  private

  def calculate_daily_recurrence
    base_time = recurrence_time || Time.current
    next_date = due_at.beginning_of_day + base_time.seconds_since_midnight

    # If time has passed on the due date, move to next day
    next_date += 1.day if next_date <= due_at

    next_date
  end

  def calculate_weekly_recurrence
    return nil unless recurrence_days.present?

    base_time = recurrence_time || Time.current
    current_day = Time.current.wday
    target_days = recurrence_days.map(&:to_i).sort

    # Find next occurrence
    target_days.each do |day|
      next_date = Time.current.beginning_of_week + day.days + base_time.seconds_since_midnight
      return next_date if next_date > Time.current
    end

    # If no day this week, get first day of next week
    first_day = target_days.first
    Time.current.beginning_of_week + 1.week + first_day.days + base_time.seconds_since_midnight
  end

  def calculate_monthly_recurrence
    base_time = recurrence_time || Time.current
    next_date = Time.current.beginning_of_month + base_time.seconds_since_midnight

    # If date has passed this month, move to next month
    next_date += 1.month if next_date < Time.current

    next_date
  end

  def calculate_yearly_recurrence
    base_time = recurrence_time || Time.current
    next_date = Time.current.beginning_of_year + base_time.seconds_since_midnight

    # If date has passed this year, move to next year
    next_date += 1.year if next_date < Time.current

    next_date
  end

  private

  def track_status_changes
    return unless saved_change_to_status?
    
    # Only track completion, not all status changes
    if done?
      self.completed_at = Time.current
      task_events.create!(
        kind: 'completed',
        reason: 'Task completed',
        user: creator,
        occurred_at: Time.current
      )
    elsif status_before_last_save == 'done' && !done?
      self.completed_at = nil
    end
  end

  def track_completion
    # This method is now handled by track_status_changes
  end

  def due_at_not_in_past_on_create
    return unless new_record?
    return unless due_at.present?
    return if Rails.env.test? # Allow past dates in tests
    
    if due_at < Time.current
      errors.add(:due_at, 'cannot be in the past')
    end
  end

  def prevent_circular_subtask_relationship
    return unless parent_task_id.present?
    
    # Check if the parent task would create a circular relationship
    if parent_task_id == id
      errors.add(:parent_task, 'cannot be self')
      return
    end
    
    # Check if any ancestor is the current task
    current_parent = parent_task
    while current_parent
      if current_parent.id == id
        errors.add(:parent_task, 'would create a circular relationship')
        break
      end
      current_parent = current_parent.parent_task
    end
  end

  def subtask_due_date_not_after_parent
    return unless parent_task_id.present? && parent_task
    return if parent_task.is_recurring? # Allow subtasks for recurring tasks
    
    if due_at > parent_task.due_at
      errors.add(:due_at, 'cannot be after parent task due date')
    end
  end

  def recurrence_pattern_requirements
    return unless is_recurring?
    
    if recurrence_pattern.blank?
      errors.add(:recurrence_pattern, 'is required for recurring tasks')
    end
    
    if recurrence_pattern == 'weekly' && recurrence_days.blank?
      errors.add(:recurrence_days, 'is required for weekly recurring tasks')
    end
    
    if recurrence_pattern == 'daily' && recurrence_time.blank?
      errors.add(:recurrence_time, 'is required for daily recurring tasks')
    end
  end

  def location_requirements
    return unless location_based?
    
    if location_latitude.blank? || location_longitude.blank?
      errors.add(:location_latitude, 'and longitude are required for location-based tasks')
    end
    
    if location_radius_meters.blank?
      errors.add(:location_radius_meters, 'is required for location-based tasks')
    end
  end
end
