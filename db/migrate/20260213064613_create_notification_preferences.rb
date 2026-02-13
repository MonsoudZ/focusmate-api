# frozen_string_literal: true

class CreateNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.boolean :nudge_enabled, default: true, null: false
      t.boolean :task_assigned_enabled, default: true, null: false
      t.boolean :list_joined_enabled, default: true, null: false
      t.boolean :task_reminder_enabled, default: true, null: false
      t.timestamps
    end
  end
end
