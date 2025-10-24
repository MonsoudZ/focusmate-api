class UpdateTaskStatusConstraint < ActiveRecord::Migration[8.0]
  def up
    begin
      remove_check_constraint :tasks, name: 'check_tasks_status'
    rescue ActiveRecord::StatementInvalid
      # Constraint doesn't exist, continue
    end

    # Update existing data to match new enum values
    Task.where(status: nil).update_all(status: 0) # pending
    Task.where(status: "pending").update_all(status: 0)
    Task.where(status: "in_progress").update_all(status: 1)
    Task.where(status: "done").update_all(status: 2)

    # Handle any remaining nil values
    Task.where(status: nil).update_all(status: 0)

    add_check_constraint :tasks, "status IN (0, 1, 2)", name: 'check_tasks_status'
  end

  def down
    begin
      remove_check_constraint :tasks, name: 'check_tasks_status'
    rescue ActiveRecord::StatementInvalid
      # Constraint doesn't exist, continue
    end
    add_check_constraint :tasks, "status IN (0, 1, 2, 3)", name: 'check_tasks_status'
  end
end
