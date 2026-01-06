class AddPriorityToTasks < ActiveRecord::Migration[8.0]
  def change
    safety_assured { add_column :tasks, :priority, :integer, default: 0, null: false }
    safety_assured { add_index :tasks, :priority }
  end
end
