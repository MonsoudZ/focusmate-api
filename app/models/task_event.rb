class TaskEvent < ApplicationRecord
  belongs_to :task
  belongs_to :user

  # Enums
  enum :kind, { created: 0, completed: 1, reassigned: 2, deleted: 3 }

  # Validations
  validates :kind, presence: true
  validates :occurred_at, presence: true
  validates :reason, length: { maximum: 500 }

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
end
