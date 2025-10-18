class AddVisibilityToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :visibility, :integer, default: 0, null: false
    add_index :tasks, :visibility
  end
end
