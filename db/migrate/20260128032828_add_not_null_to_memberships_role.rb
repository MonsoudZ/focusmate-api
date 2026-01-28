class AddNotNullToMembershipsRole < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :memberships, "role IS NOT NULL", name: "memberships_role_null", validate: false
  end
end
