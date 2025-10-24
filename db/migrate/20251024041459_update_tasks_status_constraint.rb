class UpdateTasksStatusConstraint < ActiveRecord::Migration[8.0]
  def change
    # Drop the existing constraint
    execute "ALTER TABLE tasks DROP CONSTRAINT check_tasks_status"

    # Add the new constraint that includes deleted status
    execute "ALTER TABLE tasks ADD CONSTRAINT check_tasks_status CHECK (status = ANY (ARRAY[0, 1, 2, 3]))"
  end
end
