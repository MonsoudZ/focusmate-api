# frozen_string_literal: true

class AddCheckConstraintsForEventTypeAndInviteRole < ActiveRecord::Migration[8.0]
  def change
    # Add CHECK constraint for list_invites.role (matches memberships pattern)
    # validate: false to avoid locking table during deployment
    add_check_constraint :list_invites,
                         "role::text = ANY (ARRAY['editor'::text, 'viewer'::text])",
                         name: "list_invites_role_check",
                         validate: false

    # Add CHECK constraint for analytics_events.event_type
    event_types = %w[
      task_created task_completed task_reopened task_deleted
      task_starred task_unstarred task_priority_changed task_edited
      list_created list_deleted list_shared
      app_opened session_started
    ]
    event_type_array = event_types.map { |t| "'#{t}'::text" }.join(", ")

    add_check_constraint :analytics_events,
                         "event_type::text = ANY (ARRAY[#{event_type_array}])",
                         name: "analytics_events_event_type_check",
                         validate: false
  end
end
