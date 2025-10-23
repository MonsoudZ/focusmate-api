class UpdateDailySummariesUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unique index
    remove_index :daily_summaries, name: "index_daily_summaries_unique"
    
    # Add the new unique index with the requested name
    add_index :daily_summaries, [:coaching_relationship_id, :summary_date],
              unique: true, name: "idx_daily_summaries_unique_per_rel_and_date"
  end
end
