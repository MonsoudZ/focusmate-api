class ValidateNotNullOnMembershipsRole < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :memberships, name: "memberships_role_null"
    change_column_null :memberships, :role, false
    remove_check_constraint :memberships, name: "memberships_role_null"
  end

  def down
    add_check_constraint :memberships, "role IS NOT NULL", name: "memberships_role_null", validate: false
    change_column_null :memberships, :role, true
  end
end
