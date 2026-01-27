class AddColorToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :color, :string
  end
end
