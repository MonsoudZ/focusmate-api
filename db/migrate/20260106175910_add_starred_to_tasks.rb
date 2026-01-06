class AddStarredToTasks < ActiveRecord::Migration[8.0]
  def change
    safety_assured { add_column :tasks, :starred, :boolean, default: false, null: false }
    safety_assured { add_index :tasks, :starred }
  end
end
