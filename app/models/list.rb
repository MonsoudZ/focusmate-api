class List < ApplicationRecord
  belongs_to :owner, class_name: 'User', foreign_key: 'user_id'
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy
  
  # NEW: Coaching-specific memberships
  has_many :coaching_memberships, -> { where.not(coaching_relationship_id: nil) }, 
           class_name: 'Membership'
  has_many :coaching_relationships, through: :coaching_memberships
  has_many :coaches, through: :coaching_relationships, source: :coach
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  
  # Scopes
  scope :owned_by, ->(user) { where(owner: user) }
  scope :accessible_by, ->(user) { 
    left_joins(:memberships)
      .where(memberships: { user: user })
      .or(where(owner: user))
  }
  
  # Check if user has specific role
  def role_for(user)
    return 'owner' if owner == user
    membership = memberships.find_by(user: user)
    membership&.role
  end
  
  # Check permissions
  def can_edit?(user)
    role_for(user).in?(['owner', 'editor'])
  end
  
  def can_view?(user)
    role_for(user).present?
  end
  
  def can_invite?(user)
    role_for(user).in?(['owner', 'editor'])
  end
  
  def can_add_items?(user)
    role_for(user).in?(['owner', 'editor'])
  end

  # NEW: Coaching-related methods
  
  # Check if user is a coach for this list
  def coach?(user)
    coaches.include?(user)
  end
  
  # Get all coaches for this list
  def all_coaches
    coaches.distinct
  end
  
  # Check if list has coaching relationships
  def has_coaching?
    coaching_relationships.exists?
  end
  
  # Get tasks visible to a specific coaching relationship
  def tasks_for_coaching_relationship(coaching_relationship)
    tasks.left_joins(:visibility_restrictions)
         .where(
           visibility_restrictions: { coaching_relationship: coaching_relationship }
         )
         .or(tasks.where(visibility_restrictions: { id: nil }))
  end
  
  # Get overdue tasks for coaching alerts
  def overdue_tasks
    tasks.joins(:escalation)
         .where(status: :pending)
         .where('due_at < ?', Time.current)
  end
  
  # Get tasks requiring explanation
  def tasks_requiring_explanation
    tasks.where(requires_explanation_if_missed: true)
         .where(status: :pending)
         .where('due_at < ?', Time.current)
  end
  
  # Get location-based tasks
  def location_based_tasks
    tasks.where(location_based: true)
  end
  
  # Get recurring tasks
  def recurring_tasks
    tasks.where(is_recurring: true)
  end

  # Get lists shared with a specific coach
  def self.shared_with_coach(coach)
    joins(:memberships)
      .where(memberships: { user: coach })
      .where.not(memberships: { coaching_relationship_id: nil })
  end

  # Check if list is shared with a specific coach
  def shared_with_coach?(coach)
    memberships.exists?(user: coach, coaching_relationship_id: coaching_relationships)
  end

  # Get all coaches this list is shared with
  def shared_coaches
    User.joins(:memberships)
        .where(memberships: { list: self })
        .where.not(memberships: { coaching_relationship_id: nil })
        .distinct
  end

  # Get tasks visible to a specific user
  def tasks_visible_to(user)
    if owner == user
      # Owner can see all tasks
      tasks
    elsif user.coach? && shared_with?(user)
      # Coach can see tasks based on visibility restrictions
      tasks.left_joins(:visibility_restrictions)
           .where(
             visibility_restrictions: { id: nil }
           ).or(
             tasks.joins(:visibility_restrictions)
                  .where(visibility_restrictions: { coaching_relationship: user.coaching_relationships_as_coach })
           )
    else
      # Regular member can see all tasks
      tasks
    end
  end

  # Check if list is shared with a specific user
  def shared_with?(user)
    return false unless user.coach?
    
    memberships.exists?(user: user, coaching_relationship_id: coaching_relationships)
  end
end
