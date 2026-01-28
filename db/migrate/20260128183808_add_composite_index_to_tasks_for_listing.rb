# frozen_string_literal: true

class AddCompositeIndexToTasksForListing < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Composite index for the common task listing query pattern:
    # WHERE list_id = ? AND parent_task_id IS NULL AND deleted_at IS NULL
    # list_id is most selective, then deleted_at, then parent_task_id
    add_index :tasks,
              [:list_id, :deleted_at, :parent_task_id],
              name: "index_tasks_on_list_deleted_parent",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
