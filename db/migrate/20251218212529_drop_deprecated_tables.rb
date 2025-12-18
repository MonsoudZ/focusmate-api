# frozen_string_literal: true

class DropDeprecatedTables < ActiveRecord::Migration[8.0]
  def change
    if foreign_key_exists?(:memberships, :coaching_relationships)
      remove_foreign_key :memberships, :coaching_relationships
    end

    safety_assured do
      remove_column :memberships, :coaching_relationship_id if column_exists?(:memberships, :coaching_relationship_id)
    end

    drop_table :daily_summaries, if_exists: true
    drop_table :item_visibility_restrictions, if_exists: true
    drop_table :item_escalations, if_exists: true
    drop_table :list_shares, if_exists: true
    drop_table :coaching_relationships, if_exists: true
    drop_table :examples, if_exists: true
  end
end
