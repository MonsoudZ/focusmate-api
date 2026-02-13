# frozen_string_literal: true

# Prevent invalid recurrence_pattern values at the DB level.
# The column is nullable (NULL for non-recurring tasks), so the constraint
# only fires when a value is present.
class AddCheckConstraintOnTasksRecurrencePattern < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :tasks,
                         "recurrence_pattern IS NULL OR recurrence_pattern::text = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text])",
                         name: "tasks_recurrence_pattern_check",
                         validate: false
  end
end
