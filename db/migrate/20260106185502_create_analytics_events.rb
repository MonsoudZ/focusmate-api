class CreateAnalyticsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: true
      t.references :list, null: true, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :metadata, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    safety_assured do
      add_index :analytics_events, [:user_id, :event_type, :occurred_at], name: 'idx_analytics_user_event_time'
      add_index :analytics_events, [:task_id, :event_type], name: 'idx_analytics_task_event'
      add_index :analytics_events, [:event_type, :occurred_at], name: 'idx_analytics_event_time'
      add_index :analytics_events, :occurred_at
    end
  end
end
