class AddCheckConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add check constraints for enum values (without validation)
    add_check_constraint :tasks, "status IN (0, 1, 2, 3)", name: 'tasks_status_check', validate: false
    add_check_constraint :tasks, "visibility IN (0, 1, 2, 3)", name: 'tasks_visibility_check', validate: false
    add_check_constraint :lists, "visibility IN ('private', 'shared', 'public')", name: 'lists_visibility_check', validate: false
    add_check_constraint :users, "role IN ('client', 'coach', 'admin')", name: 'users_role_check', validate: false
    add_check_constraint :coaching_relationships, "status IN ('pending', 'active', 'inactive', 'declined')", name: 'coaching_relationships_status_check', validate: false
    add_check_constraint :list_shares, "status IN ('pending', 'accepted', 'declined')", name: 'list_shares_status_check', validate: false
    add_check_constraint :memberships, "role IN ('editor', 'viewer')", name: 'memberships_role_check', validate: false
    
    # Add check constraints for positive values (without validation)
    add_check_constraint :tasks, "location_radius_meters > 0", name: 'tasks_location_radius_positive', validate: false
    add_check_constraint :tasks, "notification_interval_minutes > 0", name: 'tasks_notification_interval_positive', validate: false
    add_check_constraint :tasks, "recurrence_interval > 0", name: 'tasks_recurrence_interval_positive', validate: false
    
    # Add check constraints for valid coordinates (without validation)
    add_check_constraint :tasks, "location_latitude >= -90 AND location_latitude <= 90", name: 'tasks_latitude_range', validate: false
    add_check_constraint :tasks, "location_longitude >= -180 AND location_longitude <= 180", name: 'tasks_longitude_range', validate: false
    add_check_constraint :saved_locations, "latitude >= -90 AND latitude <= 90", name: 'saved_locations_latitude_range', validate: false
    add_check_constraint :saved_locations, "longitude >= -180 AND longitude <= 180", name: 'saved_locations_longitude_range', validate: false
    add_check_constraint :user_locations, "latitude >= -90 AND latitude <= 90", name: 'user_locations_latitude_range', validate: false
    add_check_constraint :user_locations, "longitude >= -180 AND longitude <= 180", name: 'user_locations_longitude_range', validate: false
  end
end
