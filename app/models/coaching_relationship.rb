class CoachingRelationship < ApplicationRecord
  belongs_to :coach, class_name: 'User'
  belongs_to :client, class_name: 'User'
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships
  has_many :daily_summaries, dependent: :destroy
  has_many :item_visibility_restrictions, dependent: :destroy
  
  validates :status, presence: true, inclusion: { in: %w[pending active inactive declined] }
  validates :invited_by, presence: true
  validates :coach_id, uniqueness: { scope: :client_id }
  validate :coach_and_client_different
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :pending, -> { where(status: 'pending') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :declined, -> { where(status: 'declined') }
  scope :for_coach, ->(coach) { where(coach: coach) }
  scope :for_client, ->(client) { where(client: client) }
  
  # Check if relationship is active
  def active?
    status == 'active'
  end
  
  # Check if relationship is pending
  def pending?
    status == 'pending'
  end

  # Check if relationship is declined
  def declined?
    status == 'declined'
  end
  
  # Accept the coaching relationship
  def accept!
    update!(status: 'active', accepted_at: Time.current)
  end
  
  # Deactivate the coaching relationship
  def deactivate!
    update!(status: 'inactive')
  end

  # Decline the coaching relationship
  def decline!
    update!(status: 'declined')
  end
  
  # Get all tasks across all shared lists
  def all_tasks
    Task.joins(:list)
        .where(list: lists)
        .distinct
  end
  
  # Get overdue tasks across all shared lists
  def overdue_tasks
    all_tasks.where(status: :pending)
             .where('due_at < ?', Time.current)
  end
  
  # Get tasks requiring explanation
  def tasks_requiring_explanation
    all_tasks.where(requires_explanation_if_missed: true)
             .where(status: :pending)
             .where('due_at < ?', Time.current)
  end
  
  # Get daily summary for a specific date
  def daily_summary_for(date)
    daily_summaries.find_by(summary_date: date)
  end
  
  # Create or update daily summary
  def create_daily_summary!(date)
    summary = daily_summaries.find_or_initialize_by(summary_date: date)
    
    # Calculate stats
    tasks_completed = all_tasks.where(status: :done, updated_at: date.beginning_of_day..date.end_of_day).count
    tasks_missed = all_tasks.where(status: :pending, due_at: date.beginning_of_day..date.end_of_day).count
    tasks_overdue = overdue_tasks.count
    
    summary.assign_attributes(
      tasks_completed: tasks_completed,
      tasks_missed: tasks_missed,
      tasks_overdue: tasks_overdue,
      summary_data: {
        completion_rate: tasks_completed.to_f / (tasks_completed + tasks_missed) * 100,
        overdue_count: tasks_overdue,
        last_activity: all_tasks.maximum(:updated_at)
      }
    )
    
    summary.save!
    summary
  end
  
  # Get recent daily summaries
  def recent_summaries(days = 30)
    daily_summaries.recent.limit(days)
  end

  # Get average completion rate over period
  def average_completion_rate(days = 30)
    summaries = recent_summaries(days)
    return 0 if summaries.empty?
    
    total_rate = summaries.sum(&:completion_rate)
    (total_rate / summaries.count).round(2)
  end

  # Get performance trend
  def performance_trend(days = 7)
    summaries = recent_summaries(days).order(:summary_date)
    return 'stable' if summaries.count < 2
    
    recent_rate = summaries.last.completion_rate
    previous_rate = summaries.first.completion_rate
    
    if recent_rate > previous_rate + 5
      'improving'
    elsif recent_rate < previous_rate - 5
      'declining'
    else
      'stable'
    end
  end

  # Check if daily summary should be sent
  def should_send_daily_summary?
    return false unless send_daily_summary?
    return false unless active?
    
    # Check if summary time has passed today
    return false unless daily_summary_time.present?
    
    current_time = Time.current
    summary_time_today = current_time.beginning_of_day + daily_summary_time.seconds_since_midnight
    
    current_time >= summary_time_today
  end

  # Send daily summary if conditions are met
  def send_daily_summary_if_needed!
    return unless should_send_daily_summary?
    
    summary = create_daily_summary!
    return if summary.sent?
    
    # Send notification to coach
    NotificationService.daily_summary_ready(summary)
    summary.mark_sent!
  end

  # Generate and send daily summary for a specific date
  def generate_daily_summary!(date = Date.current)
    # Check if summary already exists
    existing_summary = daily_summaries.find_by(summary_date: date)
    return existing_summary if existing_summary&.sent?
    
    # Create or update summary
    summary = existing_summary || daily_summaries.build(summary_date: date)
    
    # Calculate summary data
    tasks = client.created_tasks.where(created_at: date.beginning_of_day..date.end_of_day)
    completed_tasks = tasks.where(status: :done).count
    missed_tasks = tasks.where(status: :pending, due_at: ...date.end_of_day).count
    overdue_tasks = tasks.where(status: :pending, due_at: ...Time.current).count
    
    # Update summary data
    summary.update!(
      tasks_completed: completed_tasks,
      tasks_missed: missed_tasks,
      tasks_overdue: overdue_tasks,
      summary_data: {
        date: date.iso8601,
        client_name: client.name,
        coach_name: coach.name,
        total_tasks: tasks.count,
        completion_rate: tasks.any? ? (completed_tasks.to_f / tasks.count * 100).round(1) : 0,
        performance_notes: generate_performance_notes(completed_tasks, missed_tasks, overdue_tasks)
      }
    )
    
    # Send notification to coach
    NotificationService.daily_summary_ready(self, summary)
    
    # Send push notification to coach
    coach.devices.each do |device|
      ApnsClient.new.push(
        device_token: device.apns_token,
        title: "Daily Summary Ready",
        body: "Daily summary for #{client.name} is ready",
        payload: {
          type: "daily_summary",
          summary_id: summary.id,
          relationship_id: id
        }
      )
    end
    
    # Mark as sent
    summary.mark_sent!
    
    summary
  end

  private
  
  def coach_and_client_different
    errors.add(:client_id, 'cannot be the same as coach') if coach_id == client_id
  end

  def generate_performance_notes(completed, missed, overdue)
    notes = []
    
    if completed > 0
      notes << "#{completed} task#{'s' if completed != 1} completed"
    end
    
    if missed > 0
      notes << "#{missed} task#{'s' if missed != 1} missed"
    end
    
    if overdue > 0
      notes << "#{overdue} task#{'s' if overdue != 1} overdue"
    end
    
    notes.empty? ? "No activity recorded" : notes.join(", ")
  end
end
