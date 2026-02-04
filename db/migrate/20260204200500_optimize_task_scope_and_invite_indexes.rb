# frozen_string_literal: true

class OptimizeTaskScopeAndInviteIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :list_invites, [ :list_id, :created_at ], name: "index_list_invites_on_list_id_and_created_at",
                                                      algorithm: :concurrently

    remove_index :tasks, name: "index_tasks_on_list_deleted_parent_v2", algorithm: :concurrently
  end
end
