class FixCoachingRelationshipsStatusConstraint < ActiveRecord::Migration[8.0]
  def change
    # Remove the incorrect constraint
    remove_check_constraint :coaching_relationships, name: 'coaching_relationships_status_check'

    # Add the correct constraint
    add_check_constraint :coaching_relationships, "status IN ('pending', 'active', 'inactive', 'declined')", name: 'coaching_relationships_status_check', validate: false
  end
end
