# frozen_string_literal: true

class FixEnumConstraintMismatches < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      # Safety: abort if any rows violate the tighter constraints
      bad_status = execute("SELECT COUNT(*) FROM tasks WHERE status NOT IN (0, 1, 2)").first["count"]
      bad_visibility = execute("SELECT COUNT(*) FROM tasks WHERE visibility NOT IN (0, 1)").first["count"]
      bad_priority = execute("SELECT COUNT(*) FROM tasks WHERE priority NOT IN (0, 1, 2, 3, 4)").first["count"]
      bad_role = execute("SELECT COUNT(*) FROM users WHERE role NOT IN ('client', 'coach')").first["count"]

      if bad_status > 0 || bad_visibility > 0 || bad_priority > 0 || bad_role > 0
        raise "Data integrity violation! Fix rows first: " \
              "#{bad_status} bad status, #{bad_visibility} bad visibility, " \
              "#{bad_priority} bad priority, #{bad_role} bad role"
      end

      # --- tasks.status: remove duplicate, tighten to match enum {0,1,2} ---
      remove_check_constraint :tasks, name: "check_tasks_status"
      remove_check_constraint :tasks, name: "tasks_status_check"
      add_check_constraint :tasks, "status = ANY (ARRAY[0, 1, 2])", name: "tasks_status_check"

      # --- tasks.visibility: remove duplicate, tighten to match enum {0,1} ---
      remove_check_constraint :tasks, name: "check_tasks_visibility"
      remove_check_constraint :tasks, name: "tasks_visibility_check"
      add_check_constraint :tasks, "visibility = ANY (ARRAY[0, 1])", name: "tasks_visibility_check"

      # --- tasks.priority: add missing constraint to match enum {0,1,2,3,4} ---
      add_check_constraint :tasks, "priority = ANY (ARRAY[0, 1, 2, 3, 4])", name: "tasks_priority_check"

      # --- users.role: tighten to match model validation ['client', 'coach'] ---
      remove_check_constraint :users, name: "users_role_check"
      add_check_constraint :users,
        "role::text = ANY (ARRAY['client'::text, 'coach'::text])",
        name: "users_role_check"
    end
  end

  def down
    safety_assured do
      # --- tasks.status: restore original (loose) duplicate constraints ---
      remove_check_constraint :tasks, name: "tasks_status_check"
      add_check_constraint :tasks, "status = ANY (ARRAY[0, 1, 2, 3])", name: "tasks_status_check"
      add_check_constraint :tasks, "status = ANY (ARRAY[0, 1, 2, 3])", name: "check_tasks_status"

      # --- tasks.visibility: restore original (loose) duplicate constraints ---
      remove_check_constraint :tasks, name: "tasks_visibility_check"
      add_check_constraint :tasks, "visibility = ANY (ARRAY[0, 1, 2, 3])", name: "tasks_visibility_check"
      add_check_constraint :tasks, "visibility = ANY (ARRAY[0, 1, 2, 3])", name: "check_tasks_visibility"

      # --- tasks.priority: remove added constraint ---
      remove_check_constraint :tasks, name: "tasks_priority_check"

      # --- users.role: restore original (with admin) ---
      remove_check_constraint :users, name: "users_role_check"
      add_check_constraint :users,
        "role::text = ANY (ARRAY['client'::character varying::text, 'coach'::character varying::text, 'admin'::character varying::text])",
        name: "users_role_check"
    end
  end
end
