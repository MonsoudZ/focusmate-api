# frozen_string_literal: true

class AddForeignKeyOnRescheduleEventsUser < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :reschedule_events, :users, on_delete: :nullify, validate: false
  end
end
