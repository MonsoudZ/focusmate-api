# frozen_string_literal: true

# SoftDeletable provides soft deletion functionality for ActiveRecord models.
#
# Instead of permanently deleting records, they are marked with a deleted_at
# timestamp and excluded from default queries.
#
# Usage:
#   class Task < ApplicationRecord
#     include SoftDeletable
#   end
#
#   task.soft_delete!  # Sets deleted_at, excludes from queries
#   task.restore!      # Clears deleted_at, includes in queries
#   task.deleted?      # Returns true if soft-deleted
#
#   Task.all           # Only non-deleted records (default scope)
#   Task.with_deleted  # All records including deleted
#   Task.only_deleted  # Only deleted records
#
# Requirements:
#   - Model must have a `deleted_at` datetime column
#
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Default scope excludes soft-deleted records
    default_scope { where(deleted_at: nil) }

    # Scopes for accessing deleted records
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :not_deleted, -> { where(deleted_at: nil) }
  end

  # Soft delete the record by setting deleted_at timestamp
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # Restore a soft-deleted record
  def restore!
    update!(deleted_at: nil)
  end

  # Check if record is soft-deleted
  def deleted?
    deleted_at.present?
  end
end
