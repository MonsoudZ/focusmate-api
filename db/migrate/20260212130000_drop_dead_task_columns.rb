# frozen_string_literal: true

# Drops 3 columns from tasks that have zero references in app/ or spec/:
#   - can_be_snoozed: leftover from a removed snooze feature
#   - missed_reason_reviewed_at: review tracking never implemented
#   - missed_reason_reviewed_by_id: review tracking never implemented
class DropDeadTaskColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :tasks, :can_be_snoozed, :boolean, default: false
      remove_column :tasks, :missed_reason_reviewed_at, :datetime
      remove_column :tasks, :missed_reason_reviewed_by_id, :bigint
    end
  end
end
