class AddFieldsToItemVisibilityRestrictions < ActiveRecord::Migration[8.0]
  def change
    # Soft-delete flag
    add_column :item_visibility_restrictions, :deleted_at, :datetime

    # Active flag (default true)
    add_column :item_visibility_restrictions, :active, :boolean, default: true, null: false

    # Metadata payload
    # Use jsonb if on Postgres; use :json (or :text) otherwise.
    add_column :item_visibility_restrictions, :metadata, :jsonb, default: {}, null: false

    # Helpful indexes
    add_index :item_visibility_restrictions, :deleted_at
    add_index :item_visibility_restrictions, [:task_id, :coaching_relationship_id],
              unique: true,
              name: "index_item_vis_restrictions_on_task_and_coaching_rel"
    # Optionally, if you want to allow dupes after soft delete, you can replace the
    # unique index above with a partial unique index (Postgres):
    # remove_index :item_visibility_restrictions, name: "index_item_vis_restrictions_on_task_and_coaching_rel"
    # execute <<~SQL
    #   CREATE UNIQUE INDEX index_item_vis_restrictions_unique_live
    #   ON item_visibility_restrictions (task_id, coaching_relationship_id)
    #   WHERE deleted_at IS NULL;
    # SQL
  end
end
