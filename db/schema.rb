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

ActiveRecord::Schema[8.0].define(version: 2026_01_27_172534) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analytics_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "task_id"
    t.bigint "list_id"
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type", "occurred_at"], name: "idx_analytics_event_time"
    t.index ["list_id"], name: "index_analytics_events_on_list_id"
    t.index ["occurred_at"], name: "index_analytics_events_on_occurred_at"
    t.index ["task_id", "event_type"], name: "idx_analytics_task_event"
    t.index ["task_id"], name: "index_analytics_events_on_task_id"
    t.index ["user_id", "event_type", "occurred_at"], name: "idx_analytics_user_event_time"
    t.index ["user_id"], name: "index_analytics_events_on_user_id"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "apns_token"
    t.string "platform", default: "ios", null: false
    t.string "bundle_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "fcm_token"
    t.string "device_name"
    t.string "os_version"
    t.string "app_version"
    t.boolean "active", default: true
    t.datetime "last_seen_at"
    t.index ["active"], name: "index_devices_on_active"
    t.index ["apns_token"], name: "index_devices_on_apns_token", unique: true
    t.index ["deleted_at"], name: "index_devices_on_deleted_at"
    t.index ["fcm_token"], name: "index_devices_on_fcm_token"
    t.index ["platform"], name: "index_devices_on_platform"
    t.index ["user_id", "apns_token"], name: "index_devices_on_user_id_and_apns_token", unique: true
    t.index ["user_id", "fcm_token"], name: "index_devices_on_user_id_and_fcm_token", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  add_check_constraint "devices", "platform::text = ANY (ARRAY['ios'::character varying::text, 'android'::character varying::text])", name: "devices_platform_enum", validate: false

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

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "lists", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "visibility", default: "private", null: false
    t.integer "tasks_count", default: 0, null: false
    t.integer "list_shares_count", default: 0, null: false
    t.string "color"
    t.index ["deleted_at"], name: "index_lists_on_deleted_at"
    t.index ["user_id", "created_at"], name: "index_lists_on_user_created_at"
    t.index ["user_id", "deleted_at"], name: "index_lists_on_user_deleted_at"
    t.index ["user_id", "visibility"], name: "index_lists_on_user_and_visibility"
    t.index ["user_id"], name: "index_lists_on_user_id"
    t.index ["visibility"], name: "index_lists_on_visibility"
    t.check_constraint "visibility::text = ANY (ARRAY['private'::character varying::text, 'shared'::character varying::text, 'public'::character varying::text])", name: "lists_visibility_check"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "can_add_items", default: true
    t.boolean "receive_overdue_alerts", default: true
    t.index ["list_id", "role"], name: "index_memberships_on_list_and_role"
    t.index ["list_id", "user_id"], name: "index_memberships_on_list_user"
    t.index ["list_id"], name: "index_memberships_on_list_id"
    t.index ["user_id", "list_id"], name: "index_memberships_on_user_list"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['editor'::character varying::text, 'viewer'::character varying::text])", name: "memberships_role_check"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.bigint "task_id"
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.boolean "delivered", default: false
    t.datetime "delivered_at"
    t.text "message", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "delivery_method"
    t.datetime "deleted_at"
    t.index "((metadata ->> 'read'::text))", name: "idx_notification_logs_read_status"
    t.index "((metadata ->> 'read'::text))", name: "index_notification_logs_on_read_status"
    t.index ["created_at"], name: "index_notification_logs_on_created_at"
    t.index ["deleted_at"], name: "index_notification_logs_on_deleted_at"
    t.index ["delivered"], name: "index_notification_logs_on_delivered"
    t.index ["delivery_method"], name: "index_notification_logs_on_delivery_method"
    t.index ["notification_type"], name: "index_notification_logs_on_notification_type"
    t.index ["task_id", "created_at"], name: "index_notification_logs_on_task_created_at"
    t.index ["task_id"], name: "index_notification_logs_on_task_id"
    t.index ["user_id", "created_at"], name: "index_notification_logs_on_user_id_and_created_at"
    t.index ["user_id", "delivered"], name: "index_notification_logs_on_user_and_delivered"
    t.index ["user_id"], name: "index_notification_logs_on_user_id"
    t.check_constraint "delivery_method IS NULL OR (delivery_method::text = ANY (ARRAY['email'::character varying::text, 'push'::character varying::text, 'sms'::character varying::text, 'in_app'::character varying::text]))", name: "chk_notification_log_delivery_method"
  end

  create_table "nudges", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "from_user_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_user_id"], name: "index_nudges_on_from_user_id"
    t.index ["task_id", "from_user_id", "created_at"], name: "index_nudges_on_task_id_and_from_user_id_and_created_at"
    t.index ["task_id"], name: "index_nudges_on_task_id"
    t.index ["to_user_id"], name: "index_nudges_on_to_user_id"
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
    t.datetime "deleted_at"
    t.index ["address"], name: "index_saved_locations_on_address"
    t.index ["name"], name: "index_saved_locations_on_name"
    t.index ["user_id"], name: "index_saved_locations_on_user_id"
    t.check_constraint "latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "saved_locations_latitude_range"
    t.check_constraint "longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "saved_locations_longitude_range"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tasks_count", default: 0, null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "task_events", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.integer "kind"
    t.text "reason"
    t.datetime "occurred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["created_at", "task_id"], name: "index_task_events_on_created_at_task_id"
    t.index ["created_at"], name: "index_task_events_on_created_at"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_created_at"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_id_and_created_at"
    t.index ["task_id", "kind"], name: "index_task_events_on_task_and_kind"
    t.index ["task_id"], name: "index_task_events_on_task_id"
    t.index ["user_id"], name: "index_task_events_on_user_id"
  end

  create_table "task_tags", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_task_tags_on_tag_id"
    t.index ["task_id", "tag_id"], name: "index_task_tags_on_task_id_and_tag_id", unique: true
    t.index ["task_id"], name: "index_task_tags_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.text "title", null: false
    t.text "note"
    t.datetime "due_at"
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
    t.bigint "template_id"
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
    t.bigint "creator_id", null: false
    t.datetime "completed_at"
    t.integer "visibility", default: 0, null: false
    t.datetime "deleted_at"
    t.bigint "assigned_to_id"
    t.boolean "is_template"
    t.integer "subtasks_count", default: 0, null: false
    t.string "color"
    t.integer "priority", default: 0, null: false
    t.boolean "starred", default: false, null: false
    t.integer "position"
    t.string "template_type"
    t.date "instance_date"
    t.integer "instance_number"
    t.integer "recurrence_count"
    t.index ["assigned_to_id", "status"], name: "index_tasks_on_assigned_to_status"
    t.index ["assigned_to_id"], name: "index_tasks_on_assigned_to_id"
    t.index ["completed_at"], name: "index_tasks_on_completed_at"
    t.index ["creator_id", "completed_at"], name: "index_tasks_on_creator_completed_at"
    t.index ["creator_id", "status"], name: "index_tasks_on_creator_status"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["due_at", "completed_at"], name: "index_tasks_on_due_at_and_completed_at"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_and_status"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_status"
    t.index ["instance_date"], name: "index_tasks_on_instance_date"
    t.index ["is_recurring"], name: "index_tasks_on_is_recurring"
    t.index ["is_template"], name: "index_tasks_on_is_template"
    t.index ["list_id", "deleted_at"], name: "index_tasks_on_list_and_deleted"
    t.index ["list_id", "parent_task_id"], name: "index_tasks_on_list_and_parent"
    t.index ["list_id", "position"], name: "index_tasks_on_list_id_and_position"
    t.index ["list_id", "status", "due_at"], name: "index_tasks_on_list_status_due_at"
    t.index ["list_id", "status"], name: "index_tasks_on_list_id_and_status"
    t.index ["list_id", "updated_at"], name: "index_tasks_on_list_id_and_updated_at"
    t.index ["list_id"], name: "index_tasks_on_list_id"
    t.index ["location_based"], name: "index_tasks_on_location_based"
    t.index ["missed_reason_reviewed_by_id"], name: "index_tasks_on_missed_reason_reviewed_by_id"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["starred"], name: "index_tasks_on_starred"
    t.index ["status", "completed_at"], name: "index_tasks_on_status_and_completed"
    t.index ["status", "due_at"], name: "index_tasks_on_status_and_due_at"
    t.index ["template_id"], name: "index_tasks_on_template_id"
    t.index ["template_type"], name: "index_tasks_on_template_type"
    t.index ["visibility"], name: "index_tasks_on_visibility"
    t.check_constraint "location_latitude >= '-90'::integer::numeric AND location_latitude <= 90::numeric", name: "tasks_latitude_range"
    t.check_constraint "location_longitude >= '-180'::integer::numeric AND location_longitude <= 180::numeric", name: "tasks_longitude_range"
    t.check_constraint "location_radius_meters > 0", name: "tasks_location_radius_positive"
    t.check_constraint "notification_interval_minutes > 0", name: "tasks_notification_interval_positive"
    t.check_constraint "recurrence_interval > 0", name: "tasks_recurrence_interval_positive"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "check_tasks_status"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "tasks_status_check"
    t.check_constraint "visibility = ANY (ARRAY[0, 1, 2, 3])", name: "check_tasks_visibility"
    t.check_constraint "visibility = ANY (ARRAY[0, 1, 2, 3])", name: "tasks_visibility_check"
  end

  create_table "user_locations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.decimal "accuracy", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.jsonb "metadata", default: {}
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_user_locations_on_deleted_at"
    t.index ["recorded_at"], name: "index_user_locations_on_recorded_at"
    t.index ["source"], name: "index_user_locations_on_source"
    t.index ["user_id", "created_at"], name: "index_user_locations_on_user_created_at"
    t.index ["user_id", "deleted_at"], name: "index_user_locations_on_user_and_deleted"
    t.index ["user_id", "recorded_at"], name: "index_user_locations_on_user_id_and_recorded_at"
    t.index ["user_id", "recorded_at"], name: "index_user_locations_on_user_recorded_at"
    t.index ["user_id"], name: "index_user_locations_on_user_id"
    t.check_constraint "latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "user_locations_latitude_range"
    t.check_constraint "longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "user_locations_longitude_range"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "role", default: "client", null: false
    t.string "timezone", default: "UTC"
    t.float "latitude"
    t.float "longitude"
    t.jsonb "preferences"
    t.datetime "location_updated_at"
    t.float "current_latitude"
    t.float "current_longitude"
    t.integer "lists_count", default: 0, null: false
    t.integer "notification_logs_count", default: 0, null: false
    t.integer "devices_count", default: 0, null: false
    t.string "apple_user_id"
    t.integer "current_streak", default: 0, null: false
    t.integer "longest_streak", default: 0, null: false
    t.date "last_streak_date"
    t.index ["apple_user_id"], name: "index_users_on_apple_user_id", unique: true
    t.index ["email"], name: "index_users_on_email_unique", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "role::text = ANY (ARRAY['client'::character varying::text, 'coach'::character varying::text, 'admin'::character varying::text])", name: "users_role_check"
  end

  add_foreign_key "analytics_events", "lists"
  add_foreign_key "analytics_events", "tasks"
  add_foreign_key "analytics_events", "users"
  add_foreign_key "devices", "users"
  add_foreign_key "lists", "users"
  add_foreign_key "memberships", "lists"
  add_foreign_key "memberships", "users"
  add_foreign_key "notification_logs", "tasks"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "nudges", "tasks"
  add_foreign_key "nudges", "users", column: "from_user_id"
  add_foreign_key "nudges", "users", column: "to_user_id"
  add_foreign_key "saved_locations", "users"
  add_foreign_key "tags", "users"
  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_events", "users"
  add_foreign_key "task_tags", "tags"
  add_foreign_key "task_tags", "tasks"
  add_foreign_key "tasks", "lists"
  add_foreign_key "tasks", "tasks", column: "parent_task_id"
  add_foreign_key "tasks", "tasks", column: "template_id"
  add_foreign_key "tasks", "users", column: "assigned_to_id", on_delete: :nullify
  add_foreign_key "tasks", "users", column: "creator_id"
  add_foreign_key "tasks", "users", column: "missed_reason_reviewed_by_id"
  add_foreign_key "user_locations", "users"
end
