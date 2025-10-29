class ValidateCheckConstraints < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Validate all check constraints
    validate_check_constraint :tasks, name: 'tasks_status_check'
    validate_check_constraint :tasks, name: 'tasks_visibility_check'
    validate_check_constraint :lists, name: 'lists_visibility_check'
    validate_check_constraint :users, name: 'users_role_check'
    validate_check_constraint :coaching_relationships, name: 'coaching_relationships_status_check'
    validate_check_constraint :list_shares, name: 'list_shares_status_check'
    validate_check_constraint :memberships, name: 'memberships_role_check'

    validate_check_constraint :tasks, name: 'tasks_location_radius_positive'
    validate_check_constraint :tasks, name: 'tasks_notification_interval_positive'
    validate_check_constraint :tasks, name: 'tasks_recurrence_interval_positive'

    validate_check_constraint :tasks, name: 'tasks_latitude_range'
    validate_check_constraint :tasks, name: 'tasks_longitude_range'
    validate_check_constraint :saved_locations, name: 'saved_locations_latitude_range'
    validate_check_constraint :saved_locations, name: 'saved_locations_longitude_range'
    validate_check_constraint :user_locations, name: 'user_locations_latitude_range'
    validate_check_constraint :user_locations, name: 'user_locations_longitude_range'
  end
end
