# frozen_string_literal: true

class AddMissingCompositeIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Optimize recurring task generation job query:
    # Task.where(is_template: true, template_type: "recurring").where(deleted_at: nil)
    add_index :tasks, [:is_template, :template_type],
              where: "deleted_at IS NULL",
              name: "index_tasks_recurring_templates",
              algorithm: :concurrently,
              if_not_exists: true

    # Optimize template instance lookup:
    # template.instances.where(deleted_at: nil).order(due_at: :desc)
    add_index :tasks, [:template_id, :due_at],
              where: "deleted_at IS NULL",
              name: "index_tasks_template_instances",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
