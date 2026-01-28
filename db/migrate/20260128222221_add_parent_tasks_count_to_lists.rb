class AddParentTasksCountToLists < ActiveRecord::Migration[8.0]
  def change
    add_column :lists, :parent_tasks_count, :integer, default: 0, null: false

    # Populate existing counts
    reversible do |dir|
      dir.up do
        safety_assured do
          execute <<-SQL.squish
            UPDATE lists
            SET parent_tasks_count = (
              SELECT COUNT(*)
              FROM tasks
              WHERE tasks.list_id = lists.id
                AND tasks.parent_task_id IS NULL
                AND tasks.deleted_at IS NULL
            )
          SQL
        end
      end
    end
  end
end
