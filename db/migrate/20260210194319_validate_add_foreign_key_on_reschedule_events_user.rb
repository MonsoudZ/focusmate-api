# frozen_string_literal: true

class ValidateAddForeignKeyOnRescheduleEventsUser < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :reschedule_events, :users
  end
end
