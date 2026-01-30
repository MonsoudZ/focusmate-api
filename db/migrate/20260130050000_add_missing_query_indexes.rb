# frozen_string_literal: true

class AddMissingQueryIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Index for querying active invites for a list (e.g., "get all non-expired invites for this list")
    # Used by: ListInvitesController#index, invite validation queries
    add_index :list_invites, [ :list_id, :expires_at ],
              name: "index_list_invites_on_list_id_and_expires_at",
              algorithm: :concurrently,
              if_not_exists: true

    # Index for querying a user's recent task events (e.g., "activity feed", "recent changes")
    # Used by: Potential analytics/activity queries on user's task history
    add_index :task_events, [ :user_id, :created_at ],
              name: "index_task_events_on_user_id_and_created_at",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
