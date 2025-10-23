class AddVisibilityToLists < ActiveRecord::Migration[8.0]
  def change
    add_column :lists, :visibility, :string, null: false, default: "private"
    add_index  :lists, :visibility
  end
end
