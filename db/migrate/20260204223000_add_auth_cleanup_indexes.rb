# frozen_string_literal: true

class AddAuthCleanupIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  ACTIVE_FAMILY_EXPIRES_INDEX = "idx_refresh_tokens_expires_family_active"
  REVOKED_FAMILY_INDEX = "idx_refresh_tokens_family_revoked_not_null"

  def up
    add_index :jwt_denylists, :exp, algorithm: :concurrently, if_not_exists: true

    add_index :refresh_tokens, %i[family revoked_at],
              name: REVOKED_FAMILY_INDEX,
              where: "revoked_at IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :refresh_tokens, %i[expires_at family],
              name: ACTIVE_FAMILY_EXPIRES_INDEX,
              where: "revoked_at IS NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :refresh_tokens, name: ACTIVE_FAMILY_EXPIRES_INDEX, algorithm: :concurrently, if_exists: true
    remove_index :refresh_tokens, name: REVOKED_FAMILY_INDEX, algorithm: :concurrently, if_exists: true
    remove_index :jwt_denylists, :exp, algorithm: :concurrently, if_exists: true
  end
end
