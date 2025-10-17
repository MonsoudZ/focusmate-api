class AddCompletedAtToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :completed_at, :datetime
  end
end
