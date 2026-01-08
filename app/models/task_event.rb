# frozen_string_literal: true

class TaskEvent < ApplicationRecord
  include SoftDeletable
  belongs_to :task
  belongs_to :user

  enum :kind, {
    created: 0,
    updated: 1,
    completed: 2,
    reassigned: 3,
    deleted: 4,
    overdue: 5,
    assigned: 6,
    viewed: 7
  }

  # Soft deletion
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  # Validations
  validates :kind, presence: true
  validates :occurred_at, presence: true
  validates :reason, length: { maximum: 1000 }, allow_nil: true

  # Scopes
  scope :for_task, ->(task) { where(task: task) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_kind, ->(k) { where(kind: k) }
  scope :recent, -> { where("occurred_at >= ?", 24.hours.ago) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end
end
