class AddIsTemplateToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :is_template, :boolean
  end
end
