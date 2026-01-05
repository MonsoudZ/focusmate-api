class AddColorToLists < ActiveRecord::Migration[8.0]
  def change
    add_column :lists, :color, :string
  end
end
