# frozen_string_literal: true

class ValidateCheckConstraintsForEventTypeAndInviteRole < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :list_invites, name: "list_invites_role_check"
    validate_check_constraint :analytics_events, name: "analytics_events_event_type_check"
  end
end
