# frozen_string_literal: true

# Phase 4: Database Cleanup Migration
#
# This migration cleans up:
# 1. Unused counter cache columns on users table
# 2. Duplicate indexes on notification_logs and users
# 3. Conflicting CHECK constraints on users.role
# 4. Validates unvalidated foreign keys
#
# Run with: bundle exec rails db:migrate
#
class CleanupDatabasePhase4 < ActiveRecord::Migration[8.0]
  # Use disable_ddl_transaction! for safety with index operations
  disable_ddl_transaction!

  def up
    # =====================================================
    # 1. Remove unused counter cache columns from users
    # =====================================================
    # These columns exist but have no corresponding associations
    safety_assured do
      if column_exists?(:users, :coaching_relationships_as_coach_count)
        remove_column :users, :coaching_relationships_as_coach_count
      end

      if column_exists?(:users, :coaching_relationships_as_client_count)
        remove_column :users, :coaching_relationships_as_client_count
      end
    end

    # =====================================================
    # 2. Remove duplicate indexes on notification_logs
    # =====================================================
    # Keep: index_notification_logs_on_user_id_and_created_at
    # Remove duplicates with different names
    if index_exists?(:notification_logs, [ :user_id, :created_at ], name: :idx_notification_logs_user_created_at)
      remove_index :notification_logs, name: :idx_notification_logs_user_created_at, algorithm: :concurrently
    end

    if index_exists?(:notification_logs, [ :user_id, :created_at ], name: :index_notification_logs_on_user_created_at)
      remove_index :notification_logs, name: :index_notification_logs_on_user_created_at, algorithm: :concurrently
    end

    # =====================================================
    # 3. Remove duplicate email index on users
    # =====================================================
    # Keep: index_users_on_email_unique (the unique one)
    # Remove: index_users_on_email (non-unique duplicate)
    if index_exists?(:users, :email, name: :index_users_on_email)
      # Only remove if the unique index exists
      if index_exists?(:users, :email, name: :index_users_on_email_unique)
        remove_index :users, name: :index_users_on_email, algorithm: :concurrently
      end
    end

    # =====================================================
    # 4. Fix conflicting CHECK constraints on users.role
    # =====================================================
    # Two constraints exist:
    # - check_users_role: allows [client, coach]
    # - users_role_check: allows [client, coach, admin]
    # Remove the more restrictive one
    if constraint_exists?(:users, :check_users_role)
      remove_check_constraint :users, name: :check_users_role
    end

    # =====================================================
    # 5. Validate unvalidated foreign keys
    # =====================================================
    # tasks.assigned_to_id was created with validate: false
    if foreign_key_exists?(:tasks, :users, column: :assigned_to_id)
      validate_foreign_key :tasks, :users, column: :assigned_to_id
    end

    # Validate devices.platform CHECK constraint if it exists
    # (This is a no-op if already validated)
  end

  def down
    # =====================================================
    # Restore columns (with default values)
    # =====================================================
    unless column_exists?(:users, :coaching_relationships_as_coach_count)
      add_column :users, :coaching_relationships_as_coach_count, :integer, default: 0, null: false
    end

    unless column_exists?(:users, :coaching_relationships_as_client_count)
      add_column :users, :coaching_relationships_as_client_count, :integer, default: 0, null: false
    end

    # =====================================================
    # Restore indexes (if needed)
    # =====================================================
    unless index_exists?(:notification_logs, [ :user_id, :created_at ], name: :idx_notification_logs_user_created_at)
      add_index :notification_logs, [ :user_id, :created_at ],
                name: :idx_notification_logs_user_created_at,
                algorithm: :concurrently
    end

    unless index_exists?(:users, :email, name: :index_users_on_email)
      add_index :users, :email, name: :index_users_on_email, algorithm: :concurrently
    end

    # =====================================================
    # Restore CHECK constraint
    # =====================================================
    # Note: This may fail if there are admin users in the database
    unless constraint_exists?(:users, :check_users_role)
      add_check_constraint :users,
                           "role IN ('client', 'coach')",
                           name: :check_users_role
    end
  end

  private

  def constraint_exists?(table, name)
    query = <<~SQL
      SELECT 1 FROM pg_constraint
      WHERE conname = '#{name}'
      AND conrelid = '#{table}'::regclass
    SQL
    ActiveRecord::Base.connection.select_value(query).present?
  rescue StandardError
    false
  end
end
