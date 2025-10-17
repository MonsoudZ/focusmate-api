class ItemVisibilityRestriction < ApplicationRecord
  belongs_to :task
  belongs_to :coaching_relationship
  
  validates :task_id, uniqueness: { scope: :coaching_relationship_id }
  
  # Scopes
  scope :for_task, ->(task) { where(task: task) }
  scope :for_coaching_relationship, ->(relationship) { where(coaching_relationship: relationship) }
  
  # Check if task is visible to coaching relationship
  def visible?
    # This could be extended with more complex visibility rules
    true
  end
end
