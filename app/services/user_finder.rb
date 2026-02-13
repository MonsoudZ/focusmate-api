# frozen_string_literal: true

require "zlib"

# UserFinder provides utilities for finding users by various identifiers.
#
# Handles:
#   - Email addresses
#   - User IDs (numeric)
#   - Apple User IDs (for Sign in with Apple)
#
# Usage:
#   UserFinder.find_by_identifier("user@example.com")
#   UserFinder.find_by_identifier("123")
#   UserFinder.find_or_create_by_apple(apple_user_id: "...", email: "...", name: "...")
#
class UserFinder
  class << self
    # Find a user by email or ID
    #
    # @param identifier [String] Email address or numeric ID
    # @return [User, nil] The found user or nil
    #
    def find_by_identifier(identifier)
      return nil if identifier.blank?

      identifier = identifier.to_s.strip

      if numeric?(identifier)
        User.find_by(id: identifier)
      else
        User.find_by(email: identifier.downcase)
      end
    end

    # Find a user by email or ID, raising if not found
    #
    # @param identifier [String] Email address or numeric ID
    # @return [User] The found user
    # @raise [ActiveRecord::RecordNotFound] If user not found
    #
    def find_by_identifier!(identifier)
      find_by_identifier(identifier) || raise(ActiveRecord::RecordNotFound, "User not found: #{identifier}")
    end

    # Find or create a user from Apple Sign In.
    #
    # Uses a PostgreSQL advisory lock keyed on apple_user_id to serialize
    # concurrent requests for the same Apple account.  This eliminates the
    # TOCTOU race between the find and create steps — only one connection
    # at a time can execute this block for a given apple_user_id.
    #
    # @param apple_user_id [String] Apple's unique user identifier
    # @param email [String, nil] User's email (may be private relay)
    # @param name [String, nil] User's name (only provided on first auth)
    # @return [User] The found or created user
    #
    def find_or_create_by_apple(apple_user_id:, email: nil, name: nil)
      User.transaction do
        advisory_lock!(apple_user_id)

        # 1. Find by Apple ID
        user = User.find_by(apple_user_id: apple_user_id)
        if user
          user.update!(name: name) if name.present? && user.name.blank?
          return user
        end

        # 2. Find by email and link Apple ID
        if email.present?
          user = User.find_by(email: email.downcase)
          if user
            user.update!(apple_user_id: apple_user_id, name: name.presence || user.name)
            return user
          end
        end

        # 3. Create new user
        User.create!(
          email: email.presence || generate_private_relay_email(apple_user_id),
          apple_user_id: apple_user_id,
          name: name.presence || "User",
          password: SecureRandom.hex(16),
          timezone: "UTC"
        )
      end
    end

    private

    # Acquires a transaction-scoped advisory lock in PostgreSQL.
    # The lock is released automatically when the transaction commits/rolls back.
    # Concurrent callers with the same apple_user_id block until the lock is free.
    def advisory_lock!(apple_user_id)
      lock_key = Zlib.crc32("apple_auth:#{apple_user_id}")
      User.connection.execute("SELECT pg_advisory_xact_lock(#{lock_key})")
    end

    def numeric?(value)
      value.match?(/\A\d+\z/)
    end

    def generate_private_relay_email(apple_user_id)
      "#{apple_user_id}@privaterelay.appleid.com"
    end
  end
end
