# frozen_string_literal: true

class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # Lists counter cache on users (for owned_lists.count)
    add_column :users, :lists_count, :integer, default: 0, null: false

    # Tasks counter cache on lists (for list.tasks.count)
    add_column :lists, :tasks_count, :integer, default: 0, null: false

    # Subtasks counter cache on tasks (for task.subtasks.count)
    add_column :tasks, :subtasks_count, :integer, default: 0, null: false

    # Notification logs counter cache on users
    add_column :users, :notification_logs_count, :integer, default: 0, null: false

    # Devices counter cache on users
    add_column :users, :devices_count, :integer, default: 0, null: false

    # List shares counter cache on lists
    add_column :lists, :list_shares_count, :integer, default: 0, null: false

    # Coaching relationships counters on users
    add_column :users, :coaching_relationships_as_coach_count, :integer, default: 0, null: false
    add_column :users, :coaching_relationships_as_client_count, :integer, default: 0, null: false

    # Reset counters to accurate values
    reversible do |dir|
      dir.up do
        # Reset all counter caches
        safety_assured do
          execute <<-SQL.squish
          UPDATE users SET lists_count = (
            SELECT COUNT(*) FROM lists WHERE lists.user_id = users.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE lists SET tasks_count = (
            SELECT COUNT(*) FROM tasks WHERE tasks.list_id = lists.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE tasks SET subtasks_count = (
            SELECT COUNT(*) FROM tasks subtasks WHERE subtasks.parent_task_id = tasks.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE users SET notification_logs_count = (
            SELECT COUNT(*) FROM notification_logs WHERE notification_logs.user_id = users.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE users SET devices_count = (
            SELECT COUNT(*) FROM devices WHERE devices.user_id = users.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE lists SET list_shares_count = (
            SELECT COUNT(*) FROM list_shares WHERE list_shares.list_id = lists.id
          );
        SQL

        execute <<-SQL.squish
          UPDATE users SET coaching_relationships_as_coach_count = (
            SELECT COUNT(*) FROM coaching_relationships WHERE coaching_relationships.coach_id = users.id
          );
        SQL

          execute <<-SQL.squish
            UPDATE users SET coaching_relationships_as_client_count = (
              SELECT COUNT(*) FROM coaching_relationships WHERE coaching_relationships.client_id = users.id
            );
          SQL
        end
      end
    end
  end
end
