# frozen_string_literal: true

class AddReminderSentAtToTasks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :tasks, :reminder_sent_at, :datetime, if_not_exists: true
    add_index :tasks, [:due_at, :reminder_sent_at],
              where: "status != 2 AND deleted_at IS NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
