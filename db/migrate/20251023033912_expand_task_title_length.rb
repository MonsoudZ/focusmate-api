class ExpandTaskTitleLength < ActiveRecord::Migration[8.0]
  def change
    change_column :tasks, :title, :text, null: false
  end
end
