# frozen_string_literal: true

class ValidateUsesCountCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :list_invites, name: "list_invites_uses_count_valid"
  end
end
