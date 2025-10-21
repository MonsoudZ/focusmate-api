# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_21_172807) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "coaching_relationships", force: :cascade do |t|
    t.bigint "coach_id", null: false
    t.bigint "client_id", null: false
    t.string "status", default: "pending", null: false
    t.string "invited_by", null: false
    t.datetime "accepted_at"
    t.boolean "notify_on_completion", default: true
    t.boolean "notify_on_missed_deadline", default: true
    t.boolean "send_daily_summary", default: true
    t.time "daily_summary_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "status"], name: "index_coaching_relationships_on_client_status"
    t.index ["client_id"], name: "index_coaching_relationships_on_client_id"
    t.index ["coach_id", "client_id"], name: "index_coaching_relationships_on_coach_id_and_client_id", unique: true
    t.index ["coach_id", "status"], name: "index_coaching_relationships_on_coach_status"
    t.index ["coach_id"], name: "index_coaching_relationships_on_coach_id"
    t.index ["status"], name: "index_coaching_relationships_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'active'::character varying, 'inactive'::character varying, 'declined'::character varying]::text[])", name: "check_coaching_relationships_status"
  end

  create_table "daily_summaries", force: :cascade do |t|
    t.bigint "coaching_relationship_id", null: false
    t.date "summary_date", null: false
    t.integer "tasks_completed", default: 0
    t.integer "tasks_missed", default: 0
    t.integer "tasks_overdue", default: 0
    t.jsonb "summary_data"
    t.boolean "sent", default: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coaching_relationship_id", "summary_date"], name: "index_daily_summaries_unique", unique: true
    t.index ["coaching_relationship_id"], name: "index_daily_summaries_on_coaching_relationship_id"
    t.index ["sent"], name: "index_daily_summaries_on_sent"
    t.index ["summary_date"], name: "index_daily_summaries_on_summary_date"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "apns_token", null: false
    t.string "platform", default: "ios", null: false
    t.string "bundle_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["apns_token"], name: "index_devices_on_apns_token", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "examples", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_examples_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "item_escalations", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "escalation_level", default: "normal", null: false
    t.integer "notification_count", default: 0
    t.datetime "last_notification_at"
    t.datetime "became_overdue_at"
    t.boolean "coaches_notified", default: false
    t.datetime "coaches_notified_at"
    t.boolean "blocking_app", default: false
    t.datetime "blocking_started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocking_app"], name: "index_item_escalations_on_blocking_app"
    t.index ["escalation_level", "blocking_app"], name: "index_item_escalations_on_level_blocking"
    t.index ["escalation_level"], name: "index_item_escalations_on_escalation_level"
    t.index ["task_id", "escalation_level"], name: "index_item_escalations_on_task_level"
    t.index ["task_id"], name: "index_item_escalations_on_task_id"
    t.check_constraint "escalation_level::text = ANY (ARRAY['normal'::character varying, 'warning'::character varying, 'critical'::character varying, 'blocking'::character varying]::text[])", name: "check_item_escalations_escalation_level"
  end

  create_table "item_visibility_restrictions", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "coaching_relationship_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coaching_relationship_id"], name: "index_item_visibility_restrictions_on_coaching_relationship_id"
    t.index ["task_id", "coaching_relationship_id"], name: "index_visibility_on_task_and_relationship", unique: true
    t.index ["task_id"], name: "index_item_visibility_restrictions_on_task_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "list_shares", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.bigint "user_id"
    t.jsonb "permissions", default: {}
    t.boolean "can_view", default: true
    t.boolean "can_edit", default: false
    t.boolean "can_add_items", default: false
    t.boolean "can_delete_items", default: false
    t.boolean "receive_notifications", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.integer "role", default: 0
    t.string "status", default: "pending"
    t.string "invitation_token"
    t.datetime "invited_at"
    t.datetime "accepted_at"
    t.index ["email"], name: "index_list_shares_on_email"
    t.index ["invitation_token"], name: "index_list_shares_on_invitation_token", unique: true
    t.index ["list_id", "user_id"], name: "index_list_shares_on_list_id_and_user_id", unique: true
    t.index ["list_id"], name: "index_list_shares_on_list_id"
    t.index ["permissions"], name: "index_list_shares_on_permissions", using: :gin
    t.index ["role"], name: "index_list_shares_on_role"
    t.index ["status"], name: "index_list_shares_on_status"
    t.index ["user_id"], name: "index_list_shares_on_user_id"
  end

  create_table "lists", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_lists_on_deleted_at"
    t.index ["user_id", "created_at"], name: "index_lists_on_user_created_at"
    t.index ["user_id", "deleted_at"], name: "index_lists_on_user_deleted_at"
    t.index ["user_id"], name: "index_lists_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "can_add_items", default: true
    t.boolean "receive_overdue_alerts", default: true
    t.bigint "coaching_relationship_id"
    t.index ["coaching_relationship_id"], name: "index_memberships_on_coaching_relationship_id"
    t.index ["list_id", "user_id"], name: "index_memberships_on_list_user"
    t.index ["list_id"], name: "index_memberships_on_list_id"
    t.index ["user_id", "list_id"], name: "index_memberships_on_user_list"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.bigint "task_id"
    t.bigint "user_id", null: false
    t.string "notification_type"
    t.boolean "delivered", default: false
    t.datetime "delivered_at"
    t.text "message"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notification_logs_on_created_at"
    t.index ["delivered"], name: "index_notification_logs_on_delivered"
    t.index ["notification_type"], name: "index_notification_logs_on_notification_type"
    t.index ["task_id", "created_at"], name: "index_notification_logs_on_task_created_at"
    t.index ["task_id"], name: "index_notification_logs_on_task_id"
    t.index ["user_id", "created_at"], name: "index_notification_logs_on_user_created_at"
    t.index ["user_id"], name: "index_notification_logs_on_user_id"
  end

  create_table "saved_locations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.integer "radius_meters", default: 100
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_saved_locations_on_user_id"
  end

  create_table "task_events", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.integer "kind"
    t.text "reason"
    t.datetime "occurred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at", "task_id"], name: "index_task_events_on_created_at_task_id"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_created_at"
    t.index ["task_id"], name: "index_task_events_on_task_id"
    t.index ["user_id"], name: "index_task_events_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title", null: false
    t.text "note"
    t.datetime "due_at", null: false
    t.integer "status"
    t.boolean "strict_mode"
    t.bigint "list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_task_id"
    t.boolean "is_recurring", default: false
    t.string "recurrence_pattern"
    t.integer "recurrence_interval", default: 1
    t.jsonb "recurrence_days"
    t.time "recurrence_time"
    t.datetime "recurrence_end_date"
    t.bigint "recurring_template_id"
    t.boolean "location_based", default: false
    t.decimal "location_latitude", precision: 10, scale: 6
    t.decimal "location_longitude", precision: 10, scale: 6
    t.integer "location_radius_meters", default: 100
    t.string "location_name"
    t.boolean "notify_on_arrival", default: true
    t.boolean "notify_on_departure", default: false
    t.boolean "can_be_snoozed", default: false
    t.integer "notification_interval_minutes", default: 10
    t.boolean "requires_explanation_if_missed", default: false
    t.text "missed_reason"
    t.datetime "missed_reason_submitted_at"
    t.bigint "missed_reason_reviewed_by_id"
    t.datetime "missed_reason_reviewed_at"
    t.bigint "creator_id"
    t.datetime "completed_at"
    t.integer "visibility", default: 0, null: false
    t.datetime "deleted_at"
    t.index ["creator_id", "status"], name: "index_tasks_on_creator_status"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_and_status"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_status"
    t.index ["is_recurring"], name: "index_tasks_on_is_recurring"
    t.index ["list_id", "status", "due_at"], name: "index_tasks_on_list_status_due_at"
    t.index ["list_id", "status"], name: "index_tasks_on_list_id_and_status"
    t.index ["list_id"], name: "index_tasks_on_list_id"
    t.index ["location_based"], name: "index_tasks_on_location_based"
    t.index ["missed_reason_reviewed_by_id"], name: "index_tasks_on_missed_reason_reviewed_by_id"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["recurring_template_id"], name: "index_tasks_on_recurring_template_id"
    t.index ["status", "due_at"], name: "index_tasks_on_status_and_due_at"
    t.index ["visibility"], name: "index_tasks_on_visibility"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "check_tasks_status"
    t.check_constraint "visibility = ANY (ARRAY[0, 1, 2])", name: "check_tasks_visibility"
  end

  create_table "user_locations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.decimal "accuracy", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_at"], name: "index_user_locations_on_recorded_at"
    t.index ["user_id", "recorded_at"], name: "index_user_locations_on_user_recorded_at"
    t.index ["user_id"], name: "index_user_locations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.string "name"
    t.string "role", default: "client", null: false
    t.string "fcm_token"
    t.string "timezone", default: "UTC"
    t.string "device_token"
    t.float "latitude"
    t.float "longitude"
    t.jsonb "preferences"
    t.datetime "location_updated_at"
    t.float "current_latitude"
    t.float "current_longitude"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email"], name: "index_users_on_email_unique", unique: true
    t.index ["fcm_token"], name: "index_users_on_fcm_token"
    t.index ["jti"], name: "index_users_on_jti"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "role::text = ANY (ARRAY['client'::character varying, 'coach'::character varying]::text[])", name: "check_users_role"
  end

  add_foreign_key "coaching_relationships", "users", column: "client_id"
  add_foreign_key "coaching_relationships", "users", column: "coach_id"
  add_foreign_key "daily_summaries", "coaching_relationships"
  add_foreign_key "devices", "users"
  add_foreign_key "examples", "users"
  add_foreign_key "item_escalations", "tasks"
  add_foreign_key "item_visibility_restrictions", "coaching_relationships"
  add_foreign_key "item_visibility_restrictions", "tasks"
  add_foreign_key "list_shares", "lists"
  add_foreign_key "list_shares", "users"
  add_foreign_key "lists", "users"
  add_foreign_key "memberships", "coaching_relationships"
  add_foreign_key "memberships", "lists"
  add_foreign_key "memberships", "users"
  add_foreign_key "notification_logs", "tasks"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "saved_locations", "users"
  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_events", "users"
  add_foreign_key "tasks", "lists"
  add_foreign_key "tasks", "tasks", column: "parent_task_id"
  add_foreign_key "tasks", "tasks", column: "recurring_template_id"
  add_foreign_key "tasks", "users", column: "creator_id"
  add_foreign_key "tasks", "users", column: "missed_reason_reviewed_by_id"
  add_foreign_key "user_locations", "users"
end
