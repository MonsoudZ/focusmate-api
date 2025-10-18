class EnhanceListMembershipsForCoaching < ActiveRecord::Migration[8.0]
  def change
    # Add these fields if they don't exist

    unless column_exists?(:memberships, :can_add_items)
      add_column :memberships, :can_add_items, :boolean, default: true
    end

    unless column_exists?(:memberships, :receive_overdue_alerts)
      add_column :memberships, :receive_overdue_alerts, :boolean, default: true
    end

    # Link memberships to coaching relationships
    unless column_exists?(:memberships, :coaching_relationship_id)
      add_reference :memberships, :coaching_relationship, foreign_key: true, index: true
    end
  end
end
