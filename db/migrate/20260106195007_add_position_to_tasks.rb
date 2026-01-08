class AddPositionToTasks < ActiveRecord::Migration[8.0]
  def change
    safety_assured { add_column :tasks, :position, :integer }
    safety_assured { add_index :tasks, [ :list_id, :position ] }
  end
end
