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

ActiveRecord::Schema[8.1].define(version: 2026_02_13_045103) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "analytics_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "list_id"
    t.jsonb "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.bigint "task_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type", "occurred_at"], name: "idx_analytics_event_time"
    t.index ["list_id"], name: "index_analytics_events_on_list_id"
    t.index ["occurred_at"], name: "index_analytics_events_on_occurred_at"
    t.index ["task_id", "event_type"], name: "idx_analytics_task_event"
    t.index ["task_id"], name: "index_analytics_events_on_task_id"
    t.index ["user_id", "event_type", "occurred_at"], name: "idx_analytics_user_event_time"
    t.index ["user_id"], name: "index_analytics_events_on_user_id"
    t.check_constraint "event_type::text = ANY (ARRAY['task_created'::text, 'task_completed'::text, 'task_reopened'::text, 'task_deleted'::text, 'task_starred'::text, 'task_unstarred'::text, 'task_priority_changed'::text, 'task_edited'::text, 'list_created'::text, 'list_deleted'::text, 'list_shared'::text, 'app_opened'::text, 'session_started'::text])", name: "analytics_events_event_type_check"
  end

  create_table "devices", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "apns_token"
    t.string "app_version"
    t.string "bundle_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "device_name"
    t.string "fcm_token"
    t.datetime "last_seen_at"
    t.string "os_version"
    t.string "platform", default: "ios", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active"], name: "index_devices_on_active"
    t.index ["apns_token"], name: "index_devices_on_apns_token", unique: true
    t.index ["deleted_at"], name: "index_devices_on_deleted_at"
    t.index ["fcm_token"], name: "index_devices_on_fcm_token"
    t.index ["platform"], name: "index_devices_on_platform"
    t.index ["user_id", "fcm_token"], name: "index_devices_on_user_id_and_fcm_token", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  add_check_constraint "devices", "platform::text = ANY (ARRAY['ios'::character varying::text, 'android'::character varying::text])", name: "devices_platform_enum", validate: false

  create_table "friendships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "friend_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["friend_id"], name: "index_friendships_on_friend_id"
    t.index ["user_id", "friend_id"], name: "index_friendships_on_user_id_and_friend_id", unique: true
    t.index ["user_id"], name: "index_friendships_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "list_invites", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "inviter_id", null: false
    t.bigint "list_id", null: false
    t.integer "max_uses"
    t.string "role", default: "viewer", null: false
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["code"], name: "index_list_invites_on_code", unique: true
    t.index ["inviter_id"], name: "index_list_invites_on_inviter_id"
    t.index ["list_id", "created_at"], name: "index_list_invites_on_list_id_and_created_at"
    t.index ["list_id", "expires_at"], name: "index_list_invites_on_list_id_and_expires_at"
    t.index ["list_id"], name: "index_list_invites_on_list_id"
    t.check_constraint "role::text = ANY (ARRAY['editor'::text, 'viewer'::text])", name: "list_invites_role_check"
    t.check_constraint "uses_count >= 0 AND (max_uses IS NULL OR uses_count <= max_uses)", name: "list_invites_uses_count_valid"
  end

  create_table "lists", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.integer "parent_tasks_count", default: 0, null: false
    t.integer "tasks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "visibility", default: "private", null: false
    t.index ["deleted_at"], name: "index_lists_on_deleted_at"
    t.index ["user_id", "created_at"], name: "index_lists_on_user_created_at"
    t.index ["user_id", "deleted_at"], name: "index_lists_on_user_deleted_at"
    t.index ["user_id", "visibility"], name: "index_lists_on_user_and_visibility"
    t.index ["user_id"], name: "index_lists_on_user_id"
    t.index ["visibility"], name: "index_lists_on_visibility"
    t.check_constraint "visibility::text = ANY (ARRAY['private'::character varying::text, 'shared'::character varying::text, 'public'::character varying::text])", name: "lists_visibility_check"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "list_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["list_id", "role"], name: "index_memberships_on_list_and_role"
    t.index ["list_id", "user_id", "role"], name: "index_memberships_on_list_user_role"
    t.index ["list_id"], name: "index_memberships_on_list_id"
    t.index ["user_id", "list_id"], name: "index_memberships_on_user_id_and_list_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['editor'::character varying::text, 'viewer'::character varying::text])", name: "memberships_role_check"
  end

  create_table "nudges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_user_id", null: false
    t.bigint "task_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_user_id"], name: "index_nudges_on_from_user_id"
    t.index ["task_id", "from_user_id", "created_at"], name: "index_nudges_on_task_id_and_from_user_id_and_created_at"
    t.index ["task_id"], name: "index_nudges_on_task_id"
    t.index ["to_user_id"], name: "index_nudges_on_to_user_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "family", null: false
    t.string "jti", null: false
    t.string "replaced_by_jti"
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at", "family"], name: "idx_refresh_tokens_expires_family_active", where: "(revoked_at IS NULL)"
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["family", "revoked_at"], name: "idx_refresh_tokens_family_revoked_not_null", where: "(revoked_at IS NOT NULL)"
    t.index ["family"], name: "index_refresh_tokens_on_family"
    t.index ["jti"], name: "index_refresh_tokens_on_jti", unique: true
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_refresh_tokens_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "reschedule_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "new_due_at"
    t.datetime "previous_due_at"
    t.string "reason", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["task_id", "created_at"], name: "index_reschedule_events_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_reschedule_events_on_task_id"
    t.index ["user_id"], name: "index_reschedule_events_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "tasks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "task_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "kind"
    t.datetime "occurred_at"
    t.text "reason"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_task_events_on_created_at"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_created_at"
    t.index ["task_id", "kind"], name: "index_task_events_on_task_and_kind"
    t.index ["task_id"], name: "index_task_events_on_task_id"
    t.index ["user_id", "created_at"], name: "index_task_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_task_events_on_user_id"
  end

  create_table "task_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_task_tags_on_tag_id"
    t.index ["task_id", "tag_id"], name: "index_task_tags_on_task_id_and_tag_id", unique: true
    t.index ["task_id"], name: "index_task_tags_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.string "color"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.datetime "deleted_at"
    t.datetime "due_at"
    t.date "instance_date"
    t.integer "instance_number"
    t.boolean "is_recurring", default: false
    t.boolean "is_template"
    t.bigint "list_id", null: false
    t.boolean "location_based", default: false
    t.decimal "location_latitude", precision: 10, scale: 6
    t.decimal "location_longitude", precision: 10, scale: 6
    t.string "location_name"
    t.integer "location_radius_meters", default: 100
    t.text "missed_reason"
    t.datetime "missed_reason_submitted_at"
    t.text "note"
    t.integer "notification_interval_minutes", default: 10
    t.boolean "notify_on_arrival", default: true
    t.boolean "notify_on_departure", default: false
    t.bigint "parent_task_id"
    t.integer "position"
    t.integer "priority", default: 0, null: false
    t.integer "recurrence_count"
    t.jsonb "recurrence_days"
    t.datetime "recurrence_end_date"
    t.integer "recurrence_interval", default: 1
    t.string "recurrence_pattern"
    t.time "recurrence_time"
    t.datetime "reminder_sent_at"
    t.boolean "requires_explanation_if_missed", default: false
    t.boolean "starred", default: false, null: false
    t.integer "status", default: 0, null: false
    t.boolean "strict_mode"
    t.integer "subtasks_count", default: 0, null: false
    t.bigint "template_id"
    t.string "template_type"
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["assigned_to_id", "status"], name: "index_tasks_on_assigned_to_status"
    t.index ["assigned_to_id"], name: "index_tasks_on_assigned_to_id"
    t.index ["assigned_to_id"], name: "index_tasks_on_assigned_to_not_deleted", where: "(deleted_at IS NULL)"
    t.index ["completed_at"], name: "index_tasks_on_completed_at"
    t.index ["creator_id", "completed_at"], name: "index_tasks_on_creator_completed_at"
    t.index ["creator_id", "status"], name: "index_tasks_on_creator_status"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["due_at", "completed_at"], name: "index_tasks_on_due_at_and_completed_at"
    t.index ["due_at", "reminder_sent_at"], name: "index_tasks_on_due_at_and_reminder_sent_at", where: "((status <> 2) AND (deleted_at IS NULL))"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_and_status"
    t.index ["due_at", "status"], name: "index_tasks_on_due_at_pending", where: "((status = 0) AND (deleted_at IS NULL))"
    t.index ["instance_date"], name: "index_tasks_on_instance_date"
    t.index ["is_recurring"], name: "index_tasks_on_is_recurring"
    t.index ["is_template", "template_type"], name: "index_tasks_recurring_templates", where: "(deleted_at IS NULL)"
    t.index ["is_template"], name: "index_tasks_on_is_template"
    t.index ["list_id", "deleted_at", "parent_task_id"], name: "index_tasks_on_list_deleted_parent"
    t.index ["list_id", "deleted_at"], name: "index_tasks_on_list_and_deleted"
    t.index ["list_id", "parent_task_id"], name: "index_tasks_on_list_and_parent"
    t.index ["list_id", "position"], name: "index_tasks_on_list_id_and_position"
    t.index ["list_id", "status", "due_at"], name: "index_tasks_on_list_status_due_at"
    t.index ["list_id", "status"], name: "index_tasks_on_list_id_and_status"
    t.index ["list_id", "updated_at"], name: "index_tasks_on_list_id_and_updated_at"
    t.index ["list_id"], name: "index_tasks_on_list_id"
    t.index ["location_based"], name: "index_tasks_on_location_based"
    t.index ["note"], name: "index_tasks_on_note_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["starred"], name: "index_tasks_on_starred"
    t.index ["status", "completed_at"], name: "index_tasks_on_status_and_completed"
    t.index ["status", "due_at"], name: "index_tasks_on_status_and_due_at"
    t.index ["template_id", "due_at", "id"], name: "index_tasks_on_template_due_id_not_deleted", order: { due_at: :desc, id: :desc }, where: "((deleted_at IS NULL) AND (template_id IS NOT NULL))"
    t.index ["template_id", "due_at"], name: "index_tasks_template_instances", where: "(deleted_at IS NULL)"
    t.index ["template_id"], name: "index_tasks_on_template_id"
    t.index ["template_type"], name: "index_tasks_on_template_type"
    t.index ["title"], name: "index_tasks_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["visibility"], name: "index_tasks_on_visibility"
    t.check_constraint "location_latitude >= '-90'::integer::numeric AND location_latitude <= 90::numeric", name: "tasks_latitude_range"
    t.check_constraint "location_longitude >= '-180'::integer::numeric AND location_longitude <= 180::numeric", name: "tasks_longitude_range"
    t.check_constraint "location_radius_meters > 0", name: "tasks_location_radius_positive"
    t.check_constraint "notification_interval_minutes > 0", name: "tasks_notification_interval_positive"
    t.check_constraint "priority = ANY (ARRAY[0, 1, 2, 3, 4])", name: "tasks_priority_check"
    t.check_constraint "recurrence_interval > 0", name: "tasks_recurrence_interval_positive"
    t.check_constraint "recurrence_pattern IS NULL OR (recurrence_pattern::text = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text]))", name: "tasks_recurrence_pattern_check"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "tasks_status_check"
    t.check_constraint "visibility = ANY (ARRAY[0, 1])", name: "tasks_visibility_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "apple_user_id"
    t.datetime "created_at", null: false
    t.integer "current_streak", default: 0, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.date "last_streak_date"
    t.integer "longest_streak", default: 0, null: false
    t.string "name"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "client", null: false
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.index ["apple_user_id"], name: "index_users_on_apple_user_id", unique: true
    t.index ["email"], name: "index_users_on_email_unique", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "role::text = ANY (ARRAY['client'::text, 'coach'::text])", name: "users_role_check"
  end

  add_foreign_key "analytics_events", "lists", on_delete: :nullify
  add_foreign_key "analytics_events", "tasks", on_delete: :nullify
  add_foreign_key "analytics_events", "users", on_delete: :cascade
  add_foreign_key "devices", "users", on_delete: :cascade
  add_foreign_key "friendships", "users"
  add_foreign_key "friendships", "users", column: "friend_id"
  add_foreign_key "list_invites", "lists"
  add_foreign_key "list_invites", "users", column: "inviter_id"
  add_foreign_key "lists", "users", on_delete: :cascade
  add_foreign_key "memberships", "lists", on_delete: :cascade
  add_foreign_key "memberships", "users", on_delete: :cascade
  add_foreign_key "nudges", "tasks", on_delete: :cascade
  add_foreign_key "nudges", "users", column: "from_user_id", on_delete: :cascade
  add_foreign_key "nudges", "users", column: "to_user_id", on_delete: :cascade
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "reschedule_events", "tasks"
  add_foreign_key "reschedule_events", "users", on_delete: :nullify
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tags", "users", on_delete: :cascade
  add_foreign_key "task_events", "tasks", on_delete: :cascade
  add_foreign_key "task_events", "users", on_delete: :cascade
  add_foreign_key "task_tags", "tags", on_delete: :cascade
  add_foreign_key "task_tags", "tasks", on_delete: :cascade
  add_foreign_key "tasks", "lists", on_delete: :cascade
  add_foreign_key "tasks", "tasks", column: "parent_task_id", on_delete: :cascade
  add_foreign_key "tasks", "tasks", column: "template_id", on_delete: :cascade
  add_foreign_key "tasks", "users", column: "assigned_to_id", on_delete: :nullify
  add_foreign_key "tasks", "users", column: "creator_id", on_delete: :cascade
end
