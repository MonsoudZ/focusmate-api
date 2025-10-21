class TaskEvent < ApplicationRecord
  belongs_to :task
  belongs_to :user

  # Enums
  enum :kind, { created: 0, updated: 1, completed: 2, reassigned: 3, deleted: 4 }

  # Validations
  validates :kind, presence: true
  validates :occurred_at, presence: true
  validates :reason, length: { maximum: 500 }

  # Callbacks
  before_validation :set_occurred_at, if: -> { occurred_at.blank? }

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :with_reasons, -> { where.not(reason: [ nil, "" ]) }

  # Class methods
  def self.audit_trail_for(task)
    where(task: task).recent.includes(:user)
  end

  def self.reassignments_for(task)
    where(task: task, kind: :reassigned).recent.includes(:user)
  end

  private

  def set_occurred_at
    self.occurred_at = Time.current
  end
end
