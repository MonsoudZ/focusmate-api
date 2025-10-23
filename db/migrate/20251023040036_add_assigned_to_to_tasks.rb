class AddAssignedToToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :assigned_to_id, :bigint
    add_index :tasks, :assigned_to_id
  end
end
