class UpdateTaskStatusEnum < ActiveRecord::Migration[8.0]
  def up
    # First, update the check constraint to allow new status values
    execute "ALTER TABLE tasks DROP CONSTRAINT check_tasks_status"
    execute "ALTER TABLE tasks ADD CONSTRAINT check_tasks_status CHECK (status = ANY (ARRAY[0, 1, 2, 3]))"
    
    # Update existing status values to accommodate new enum
    # pending: 0 -> 0 (no change)
    # done: 1 -> 2 (moved to make room for in_progress)
    # deleted: 2 -> 3 (moved to make room for in_progress)
    
    execute "UPDATE tasks SET status = 2 WHERE status = 1" # done: 1 -> 2
    execute "UPDATE tasks SET status = 3 WHERE status = 2" # deleted: 2 -> 3
  end

  def down
    # Revert the changes
    execute "UPDATE tasks SET status = 2 WHERE status = 3" # deleted: 3 -> 2
    execute "UPDATE tasks SET status = 1 WHERE status = 2" # done: 2 -> 1
    
    # Restore original check constraint
    execute "ALTER TABLE tasks DROP CONSTRAINT check_tasks_status"
    execute "ALTER TABLE tasks ADD CONSTRAINT check_tasks_status CHECK (status = ANY (ARRAY[0, 1, 2]))"
  end
end
