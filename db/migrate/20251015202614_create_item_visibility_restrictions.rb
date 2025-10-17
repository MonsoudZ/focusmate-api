class CreateItemVisibilityRestrictions < ActiveRecord::Migration[8.0]
  def change
    create_table :item_visibility_restrictions do |t|
      t.references :task, null: false, foreign_key: true, index: true
      t.references :coaching_relationship, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :item_visibility_restrictions, 
              [:task_id, :coaching_relationship_id], 
              unique: true,
              name: 'index_visibility_on_task_and_relationship'
  end
end