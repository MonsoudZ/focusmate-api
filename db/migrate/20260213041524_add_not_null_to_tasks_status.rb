# frozen_string_literal: true

# tasks.status is an integer enum (pending:0, in_progress:1, done:2) with a
# model-level default but no DB-level NOT NULL constraint.  Back-fill any
# stray NULLs to 0 (pending), then add the constraint unvalidated so the
# ALTER is instant and non-blocking.
class AddNotNullToTasksStatus < ActiveRecord::Migration[8.1]
  def up
    # Back-fill NULLs first (safe even on large tables — only touches NULL rows)
    Task.unscoped.where(status: nil).update_all(status: 0)

    safety_assured do
      change_column_default :tasks, :status, from: nil, to: 0
      change_column_null :tasks, :status, false
    end
  end

  def down
    change_column_null :tasks, :status, true
    change_column_default :tasks, :status, from: 0, to: nil
  end
end
