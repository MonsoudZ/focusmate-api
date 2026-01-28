# frozen_string_literal: true

class AddOnDeleteToForeignKeys < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      # ── Ownership chains: CASCADE ──────────────────────────────────
      # When the parent is deleted, children are meaningless without it.

      # User owns lists, devices, memberships, tags, refresh_tokens, created_tasks
      replace_fk :lists,            :users,  on_delete: :cascade
      replace_fk :devices,          :users,  on_delete: :cascade
      replace_fk :memberships,      :users,  on_delete: :cascade
      replace_fk :tags,             :users,  on_delete: :cascade
      replace_fk :refresh_tokens,   :users,  on_delete: :cascade
      replace_fk :tasks,            :users,  column: :creator_id, on_delete: :cascade

      # List owns tasks and memberships
      replace_fk :tasks,            :lists,  on_delete: :cascade
      replace_fk :memberships,      :lists,  on_delete: :cascade

      # Task owns subtasks, instances, events, tags, nudges
      replace_fk :tasks,            :tasks,  column: :parent_task_id, on_delete: :cascade
      replace_fk :tasks,            :tasks,  column: :template_id,    on_delete: :cascade
      replace_fk :task_events,      :tasks,  on_delete: :cascade
      replace_fk :task_tags,        :tasks,  on_delete: :cascade
      replace_fk :nudges,           :tasks,  on_delete: :cascade

      # Tag owns task_tags
      replace_fk :task_tags,        :tags,   on_delete: :cascade

      # Nudges and task_events reference acting users — cascade to avoid FK violations on user deletion
      replace_fk :task_events,      :users,  on_delete: :cascade
      replace_fk :nudges,           :users,  column: :from_user_id, on_delete: :cascade
      replace_fk :nudges,           :users,  column: :to_user_id,   on_delete: :cascade

      # Analytics: cascade user (NOT NULL owner), nullify optional task/list refs
      replace_fk :analytics_events, :users,  on_delete: :cascade
      replace_fk :analytics_events, :tasks,  on_delete: :nullify
      replace_fk :analytics_events, :lists,  on_delete: :nullify

      # ── Optional references: NULLIFY ──────────────────────────────
      # assigned_to_id already has on_delete: :nullify — skip it
      replace_fk :tasks, :users, column: :missed_reason_reviewed_by_id, on_delete: :nullify
    end
  end

  def down
    safety_assured do
      # Restore all FKs to default (no on_delete / RESTRICT)
      replace_fk :lists,            :users,  on_delete: nil
      replace_fk :devices,          :users,  on_delete: nil
      replace_fk :memberships,      :users,  on_delete: nil
      replace_fk :tags,             :users,  on_delete: nil
      replace_fk :refresh_tokens,   :users,  on_delete: nil
      replace_fk :tasks,            :users,  column: :creator_id, on_delete: nil
      replace_fk :tasks,            :lists,  on_delete: nil
      replace_fk :memberships,      :lists,  on_delete: nil
      replace_fk :tasks,            :tasks,  column: :parent_task_id, on_delete: nil
      replace_fk :tasks,            :tasks,  column: :template_id,    on_delete: nil
      replace_fk :task_events,      :tasks,  on_delete: nil
      replace_fk :task_tags,        :tasks,  on_delete: nil
      replace_fk :nudges,           :tasks,  on_delete: nil
      replace_fk :task_tags,        :tags,   on_delete: nil
      replace_fk :task_events,      :users,  on_delete: nil
      replace_fk :nudges,           :users,  column: :from_user_id, on_delete: nil
      replace_fk :nudges,           :users,  column: :to_user_id,   on_delete: nil
      replace_fk :analytics_events, :users,  on_delete: nil
      replace_fk :analytics_events, :tasks,  on_delete: nil
      replace_fk :analytics_events, :lists,  on_delete: nil
      replace_fk :tasks,            :users,  column: :missed_reason_reviewed_by_id, on_delete: nil
    end
  end

  private

  def replace_fk(from_table, to_table, column: nil, on_delete: nil)
    remove_opts = column ? { column: column } : { to_table: to_table }
    remove_foreign_key from_table, **remove_opts

    add_opts = {}
    add_opts[:column] = column if column
    add_opts[:on_delete] = on_delete if on_delete
    add_foreign_key from_table, to_table, **add_opts
  end
end
