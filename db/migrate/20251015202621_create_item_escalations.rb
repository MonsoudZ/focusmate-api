class CreateItemEscalations < ActiveRecord::Migration[8.0]
  def change
    create_table :item_escalations do |t|
      t.references :task, null: false, foreign_key: true, index: true
      t.string :escalation_level, default: 'normal', null: false
      t.integer :notification_count, default: 0
      t.datetime :last_notification_at
      t.datetime :became_overdue_at
      t.boolean :coaches_notified, default: false
      t.datetime :coaches_notified_at
      t.boolean :blocking_app, default: false
      t.datetime :blocking_started_at
      
      t.timestamps
    end
    
    add_index :item_escalations, :escalation_level
    add_index :item_escalations, :blocking_app
  end
end