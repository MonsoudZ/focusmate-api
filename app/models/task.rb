class Task < ApplicationRecord
  belongs_to :list
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  has_many :task_events, dependent: :destroy
  
  # NEW associations for coaching features
  belongs_to :parent_task, class_name: 'Task', optional: true
  belongs_to :recurring_template, class_name: 'Task', optional: true
  has_many :subtasks, class_name: 'Task', foreign_key: :parent_task_id, dependent: :destroy
  has_many :recurring_instances, class_name: 'Task', foreign_key: :recurring_template_id, dependent: :destroy
  has_many :visibility_restrictions, class_name: 'ItemVisibilityRestriction', 
           foreign_key: :task_id, dependent: :destroy
  has_one :escalation, class_name: 'ItemEscalation', foreign_key: :task_id, dependent: :destroy
  has_many :notification_logs, foreign_key: :task_id, dependent: :destroy
  belongs_to :missed_reason_reviewed_by, class_name: 'User', optional: true
  
  # Enums
  enum :status, { pending: 0, done: 1, deleted: 2 }
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
  validates :due_at, presence: true
  validates :strict_mode, inclusion: { in: [true, false] }
  
  # Scopes
  scope :active, -> { where.not(status: :deleted) }
  scope :pending, -> { where(status: :pending) }
  scope :completed, -> { where(status: :done) }
  scope :done, -> { where(status: :done) }
  scope :complete, -> { where(status: :done) }
  scope :due_soon, -> { where('due_at <= ?', 1.day.from_now) }
  scope :overdue, -> { where(status: :pending).where('due_at < ?', Time.current) }
  scope :awaiting_explanation, -> { where(requires_explanation_if_missed: true, status: :pending).where('due_at < ?', Time.current) }
  scope :templates, -> { where(is_recurring: true, recurring_template_id: nil) }
  scope :instances, -> { where.not(recurring_template_id: nil) }
  scope :incomplete, -> { where.not(status: :done) }
  
  # Callbacks
  after_create :create_task_event
  after_update :create_task_event, if: :saved_change_to_status?
  after_commit :broadcast_create, on: :create
  after_commit :broadcast_update, on: :update
  
  # Business logic methods
  def complete!
    update!(status: 1)
    
    # Clear escalation if exists
    escalation&.update!(
      escalation_level: 'normal',
      notification_count: 0,
      blocking_app: false,
      blocking_started_at: nil
    ) if escalation
  end
  
  def uncomplete!
    update!(status: 0)
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
    save!
    create_task_event(user: user, kind: :deleted, reason: reason)
    true
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
    (subtasks.complete.count.to_f / subtasks.count * 100).round(1)
  end

  # Check if task should block the app
  def should_block_app?
    return false unless overdue?
    return false if can_be_snoozed?
    
    # Block app based on priority and time overdue
    case priority
    when 3 # Urgent
      minutes_overdue > 120
    when 2 # High
      minutes_overdue > 240
    else # Medium/Low
      minutes_overdue > 480 # 8 hours
    end
  end

  # Create escalation record if it doesn't exist
  def create_escalation!
    return escalation if escalation.present?
    
    ItemEscalation.create!(
      task: self,
      escalation_level: 'normal',
      notification_count: 0,
      became_overdue_at: Time.current
    )
  end

  # Check if all subtasks are completed
  def all_subtasks_completed?
    return true if subtasks.empty?
    subtasks.all?(&:done?)
  end

  # Schedule completion handler when task is completed
  after_commit :schedule_completion_handler, on: :update, if: :saved_change_to_status?
  
  # Check location trigger for location-based tasks
  after_commit :check_location_trigger, on: :create, if: :location_based?

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
  
  # Check if task is location-based
  def location_based?
    location_based && location_latitude.present? && location_longitude.present?
  end
  
  # Check if task is recurring
  def recurring?
    is_recurring && recurring_template_id.present?
  end
  
  # Get location coordinates
  def coordinates
    return nil unless location_based?
    [location_latitude, location_longitude]
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
  
  # Submit missed reason
  def submit_missed_reason!(reason, user)
    return false unless requires_explanation_if_missed?
    return false if missed_reason.present?
    
    update!(
      missed_reason: reason,
      missed_reason_submitted_at: Time.current,
      missed_reason_submitted_by: user
    )
    true
  end
  
  # Review missed reason (coach action)
  def review_missed_reason!(reviewer, approved: true)
    return false unless missed_reason.present?
    return false if missed_reason_reviewed_at.present?
    
    update!(
      missed_reason_reviewed_by: reviewer,
      missed_reason_reviewed_at: Time.current,
      missed_reason_approved: approved
    )
    true
  end
  
  # Check if task can be snoozed
  def can_be_snoozed?
    can_be_snoozed && pending?
  end
  
  # Get escalation level
  def escalation_level
    escalation&.escalation_level || 'normal'
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

  def broadcast_create = Broadcasts.task_changed(self, event: "created")
  def broadcast_update = Broadcasts.task_changed(self, event: "updated")

  # Recurring template methods
  def is_recurring?
    is_recurring == true
  end

  def is_template?
    is_recurring? && recurring_template_id.nil?
  end

  def is_instance?
    recurring_template_id.present?
  end

  # Generate next instance of recurring template
  def generate_next_instance
    return nil unless is_template?
    return nil if recurrence_end_date.present? && recurrence_end_date < Time.current

    # Calculate next due date based on recurrence pattern
    next_due_at = calculate_next_due_date
    return nil unless next_due_at

    # Create new instance
    instance = list.tasks.build(
      title: title,
      description: description,
      note: note,
      due_at: next_due_at,
      priority: priority,
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

  # Get all instances of this template
  def recurring_instances
    Task.where(recurring_template_id: id)
  end

  # Get next due date based on recurrence pattern
  def calculate_next_due_date
    return nil unless is_template?

    case recurrence_pattern
    when 'daily'
      calculate_daily_recurrence
    when 'weekly'
      calculate_weekly_recurrence
    when 'monthly'
      calculate_monthly_recurrence
    when 'yearly'
      calculate_yearly_recurrence
    else
      nil
    end
  end

  private

  def calculate_daily_recurrence
    base_time = recurrence_time || Time.current
    next_date = Time.current.beginning_of_day + base_time.seconds_since_midnight
    
    # If time has passed today, move to tomorrow
    next_date += 1.day if next_date < Time.current
    
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
end
