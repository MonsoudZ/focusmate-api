# frozen_string_literal: true

class AddUsesCountCheckConstraintToListInvites < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :list_invites,
      "uses_count >= 0 AND (max_uses IS NULL OR uses_count <= max_uses)",
      name: "list_invites_uses_count_valid",
      validate: false
  end
end
