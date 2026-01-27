class AddStreakFieldsToUsers < ActiveRecord::Migration[8.0]
    def change
      safety_assured do
        add_column :users, :current_streak, :integer, default: 0, null: false
        add_column :users, :longest_streak, :integer, default: 0, null: false
        add_column :users, :last_streak_date, :date
      end
    end
end
