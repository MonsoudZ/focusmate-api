# frozen_string_literal: true

# revenue_plans table has zero references in app/ — no model, controller,
# serializer, service, or spec.  Dropping to eliminate dead schema.
class DropRevenuePlansTable < ActiveRecord::Migration[8.1]
  def up
    drop_table :revenue_plans, if_exists: true
  end

  def down
    create_table :revenue_plans do |t|
      t.decimal  :call_to_close_rate,   precision: 5, scale: 4, default: "0.2",    null: false
      t.string   :currency_code,        limit: 3,               default: "USD",    null: false
      t.integer  :goal_cents,                                                       null: false
      t.decimal  :lead_to_call_rate,    precision: 5, scale: 4, default: "0.2",    null: false
      t.string   :name,                                                             null: false
      t.text     :notes
      t.decimal  :outbound_reply_rate,  precision: 5, scale: 4, default: "0.1",    null: false
      t.string   :period,                                       default: "month",  null: false
      t.integer  :price_cents,                                                      null: false
      t.string   :status,                                       default: "active", null: false
      t.bigint   :user_id,                                                          null: false
      t.integer  :working_days,                                 default: 20,       null: false

      t.timestamps
    end

    add_index :revenue_plans, [ :user_id, :status ], name: "index_revenue_plans_on_user_id_and_status"
    add_index :revenue_plans, :user_id,            name: "index_revenue_plans_on_user_id"
    add_foreign_key :revenue_plans, :users
  end
end
