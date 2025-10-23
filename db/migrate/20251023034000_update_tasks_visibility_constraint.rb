class UpdateTasksVisibilityConstraint < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :tasks, name: 'check_tasks_visibility'
    add_check_constraint :tasks, "visibility IN (0, 1, 2, 3)", name: 'check_tasks_visibility'
  end

  def down
    remove_check_constraint :tasks, name: 'check_tasks_visibility'
    add_check_constraint :tasks, "visibility IN (0, 1, 2)", name: 'check_tasks_visibility'
  end
end
