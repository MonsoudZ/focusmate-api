# frozen_string_literal: true

class AddPermissionQueryIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Composite index for permission checks: list_id + user_id + role
    # Used by: List#can_edit?, ListPolicy#editor?, TaskUpdateService#can_edit_task?
    # This optimizes queries like: memberships.exists?(user_id: X, role: "editor")
    add_index :memberships, [ :list_id, :user_id, :role ],
              name: "index_memberships_on_list_user_role",
              if_not_exists: true,
              algorithm: :concurrently

    # Partial index for active (non-deleted) tasks by assigned user
    # Optimizes: Task.where(assigned_to_id: X, deleted_at: nil)
    add_index :tasks, [ :assigned_to_id ],
              name: "index_tasks_on_assigned_to_not_deleted",
              where: "deleted_at IS NULL",
              if_not_exists: true,
              algorithm: :concurrently

    # Partial index for pending tasks due date lookups (overdue queries)
    # Optimizes: Task.pending.where("due_at < ?", Time.current)
    add_index :tasks, [ :due_at, :status ],
              name: "index_tasks_on_due_at_pending",
              where: "status = 0 AND deleted_at IS NULL",
              if_not_exists: true,
              algorithm: :concurrently

    # Composite index for list task queries with parent filtering
    # Optimizes: tasks.where(list_id: X, parent_task_id: nil, deleted_at: nil)
    # Note: Using 3 columns as recommended by strong_migrations
    # is_template is excluded since it's rare and can use existing indexes
    add_index :tasks, [ :list_id, :deleted_at, :parent_task_id ],
              name: "index_tasks_on_list_deleted_parent_v2",
              if_not_exists: true,
              algorithm: :concurrently
  end
end
