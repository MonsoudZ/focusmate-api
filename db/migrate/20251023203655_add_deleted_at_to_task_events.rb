class AddDeletedAtToTaskEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :task_events, :deleted_at, :datetime
  end
end
