class AddDeletedAtToDailySummaries < ActiveRecord::Migration[8.0]
  def change
    add_column :daily_summaries, :deleted_at, :datetime
  end
end
