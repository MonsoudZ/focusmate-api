class AddDeletedAtToListAndTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :lists, :deleted_at, :datetime
    add_column :tasks, :deleted_at, :datetime
    
    add_index :lists, :deleted_at
    add_index :tasks, :deleted_at
  end
end
