# frozen_string_literal: true

class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :jti, null: false
      t.string :family, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :replaced_by_jti

      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, :jti, unique: true
    add_index :refresh_tokens, :family
    add_index :refresh_tokens, [ :user_id, :revoked_at ]
    add_index :refresh_tokens, :expires_at
  end
end
