class AddMissingTaskFields < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for performance (fields already exist)
    add_index :tasks, :parent_task_id unless index_exists?(:tasks, :parent_task_id)
    add_index :tasks, :recurring_template_id unless index_exists?(:tasks, :recurring_template_id)
    add_index :tasks, :location_based unless index_exists?(:tasks, :location_based)
    add_index :tasks, [ :status, :due_at ] unless index_exists?(:tasks, [ :status, :due_at ])
    add_index :tasks, [ :list_id, :status ] unless index_exists?(:tasks, [ :list_id, :status ])
  end
end
