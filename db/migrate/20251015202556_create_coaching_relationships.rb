class CreateCoachingRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :coaching_relationships do |t|
      t.references :coach, null: false, foreign_key: { to_table: :users }
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'pending', null: false
      t.string :invited_by, null: false
      t.datetime :accepted_at
      
      # Notification preferences
      t.boolean :notify_on_completion, default: true
      t.boolean :notify_on_missed_deadline, default: true
      t.boolean :send_daily_summary, default: true
      t.time :daily_summary_time
      
      t.timestamps
    end
    
    add_index :coaching_relationships, [:coach_id, :client_id], unique: true
    add_index :coaching_relationships, :status
  end
end