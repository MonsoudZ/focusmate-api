class RemoveDuplicateTaskEventsIndexes < ActiveRecord::Migration[8.0]
  def change
    # index_task_events_on_created_at_task_id (created_at, task_id) is redundant —
    # there's already a standalone created_at index plus (task_id, created_at) indexes.
    remove_index :task_events, name: :index_task_events_on_created_at_task_id

    # index_task_events_on_task_id_and_created_at is an exact duplicate of
    # index_task_events_on_task_created_at (both on task_id, created_at).
    remove_index :task_events, name: :index_task_events_on_task_id_and_created_at
  end
end
