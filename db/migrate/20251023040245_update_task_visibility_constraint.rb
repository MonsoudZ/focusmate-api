class UpdateTaskVisibilityConstraint < ActiveRecord::Migration[8.0]
  def up
    begin
      remove_check_constraint :tasks, name: 'check_tasks_visibility'
    rescue ActiveRecord::StatementInvalid
      # Constraint doesn't exist, continue
    end

    # Update existing data to match new enum values
    Task.where(visibility: nil).update_all(visibility: 0) # visible_to_all
    Task.where(visibility: "visible_to_all").update_all(visibility: 0)
    Task.where(visibility: "private_task").update_all(visibility: 1)
    Task.where(visibility: "hidden_from_coaches").update_all(visibility: 2)
    Task.where(visibility: "coaching_only").update_all(visibility: 3)

    add_check_constraint :tasks, "visibility IN (0, 1, 2, 3)", name: 'check_tasks_visibility'
  end

  def down
    begin
      remove_check_constraint :tasks, name: 'check_tasks_visibility'
    rescue ActiveRecord::StatementInvalid
      # Constraint doesn't exist, continue
    end
    add_check_constraint :tasks, "visibility IN (0, 1, 2, 3)", name: 'check_tasks_visibility'
  end
end
