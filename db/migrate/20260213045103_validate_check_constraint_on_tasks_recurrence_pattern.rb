# frozen_string_literal: true

class ValidateCheckConstraintOnTasksRecurrencePattern < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :tasks, name: "tasks_recurrence_pattern_check"
  end
end
