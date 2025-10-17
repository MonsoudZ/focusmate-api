class CreateNotificationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_logs do |t|
      t.references :task, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :notification_type
      t.boolean :delivered, default: false
      t.datetime :delivered_at
      t.text :message
      t.jsonb :metadata
      
      t.timestamps
    end
    
    add_index :notification_logs, :notification_type
    add_index :notification_logs, :delivered
    add_index :notification_logs, :created_at
  end
end