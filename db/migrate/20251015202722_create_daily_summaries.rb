class CreateDailySummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_summaries do |t|
      t.references :coaching_relationship, null: false, foreign_key: true, index: true
      t.date :summary_date, null: false
      t.integer :tasks_completed, default: 0
      t.integer :tasks_missed, default: 0
      t.integer :tasks_overdue, default: 0
      t.jsonb :summary_data
      t.boolean :sent, default: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :daily_summaries, [ :coaching_relationship_id, :summary_date ],
              unique: true,
              name: 'index_daily_summaries_unique'
    add_index :daily_summaries, :summary_date
    add_index :daily_summaries, :sent
  end
end
