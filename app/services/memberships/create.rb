# frozen_string_literal: true

module Memberships
  class Create
    class Error < StandardError; end
    class NotFound < Error; end
    class BadRequest < Error; end
    class Conflict < Error; end

    ALLOWED_ROLES = %w[viewer editor].freeze

    def self.call!(list:, inviter:, user_identifier:, role:)
      new(list:, inviter:, user_identifier:, role:).call!
    end

    def initialize(list:, inviter:, user_identifier:, role:)
      @list = list
      @inviter = inviter
      @user_identifier = user_identifier.to_s.strip
      @role = role.to_s.downcase.strip.presence || "viewer"
    end

    def call!
      raise BadRequest, "user_identifier is required" if @user_identifier.blank?
      raise BadRequest, "Invalid role" unless ALLOWED_ROLES.include?(@role)

      target_user = find_user(@user_identifier)
      raise NotFound, "User not found" unless target_user

      raise Conflict, "Cannot invite yourself" if target_user.id == @inviter.id
      raise Conflict, "User is already a member of this list" if @list.memberships.exists?(user_id: target_user.id)

      @list.memberships.create!(user: target_user, role: @role)
    end

    private

    def find_user(identifier)
      if identifier.match?(/\A\d+\z/)
        User.find_by(id: identifier)
      else
        User.find_by(email: identifier.downcase)
      end
    end
  end
end
