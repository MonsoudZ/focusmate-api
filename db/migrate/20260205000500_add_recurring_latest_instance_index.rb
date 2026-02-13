# frozen_string_literal: true

class AddRecurringLatestInstanceIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_tasks_on_template_due_id_not_deleted"

  def up
    add_index :tasks,
              [ :template_id, :due_at, :id ],
              order: { due_at: :desc, id: :desc },
              where: "deleted_at IS NULL AND template_id IS NOT NULL",
              name: INDEX_NAME,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :tasks,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
