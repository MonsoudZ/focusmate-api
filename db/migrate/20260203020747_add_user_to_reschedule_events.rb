# frozen_string_literal: true

class AddUserToRescheduleEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :reschedule_events, :user, null: true, index: { algorithm: :concurrently }
  end
end
