class EnhanceTasksWithNewFeatures < ActiveRecord::Migration[8.0]
  def change
    # Add parent_task_id for subtasks
    add_reference :tasks, :parent_task, foreign_key: { to_table: :tasks }, index: true

    # Recurring task fields
    add_column :tasks, :is_recurring, :boolean, default: false
    add_column :tasks, :recurrence_pattern, :string
    add_column :tasks, :recurrence_interval, :integer, default: 1
    add_column :tasks, :recurrence_days, :jsonb
    add_column :tasks, :recurrence_time, :time
    add_column :tasks, :recurrence_end_date, :datetime
    add_reference :tasks, :recurring_template, foreign_key: { to_table: :tasks }, index: true

    # Location fields
    add_column :tasks, :location_based, :boolean, default: false
    add_column :tasks, :location_latitude, :decimal, precision: 10, scale: 6
    add_column :tasks, :location_longitude, :decimal, precision: 10, scale: 6
    add_column :tasks, :location_radius_meters, :integer, default: 100
    add_column :tasks, :location_name, :string
    add_column :tasks, :notify_on_arrival, :boolean, default: true
    add_column :tasks, :notify_on_departure, :boolean, default: false

    # Accountability fields
    add_column :tasks, :can_be_snoozed, :boolean, default: false
    add_column :tasks, :notification_interval_minutes, :integer, default: 10
    add_column :tasks, :requires_explanation_if_missed, :boolean, default: false
    add_column :tasks, :missed_reason, :text
    add_column :tasks, :missed_reason_submitted_at, :datetime
    add_reference :tasks, :missed_reason_reviewed_by, foreign_key: { to_table: :users }
    add_column :tasks, :missed_reason_reviewed_at, :datetime

    # Add creator if you don't have it
    unless column_exists?(:tasks, :creator_id)
      add_reference :tasks, :creator, foreign_key: { to_table: :users }, index: true
    end

    # Add indexes for performance
    add_index :tasks, :location_based
    add_index :tasks, :is_recurring
    add_index :tasks, [ :list_id, :status ]
    add_index :tasks, [ :due_at, :status ]
  end
end
