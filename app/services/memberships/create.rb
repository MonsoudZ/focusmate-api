# frozen_string_literal: true

module Memberships
  class Create
    class NotFound < ApplicationError::NotFound; end
    class BadRequest < ApplicationError::BadRequest; end
    class Conflict < ApplicationError::Conflict; end
    class Forbidden < ApplicationError::Forbidden; end

    ALLOWED_ROLES = %w[viewer editor].freeze

    def self.call!(list:, inviter:, user_identifier: nil, friend_id: nil, role:)
      new(list:, inviter:, user_identifier:, friend_id:, role:).call!
    end

    def initialize(list:, inviter:, user_identifier: nil, friend_id: nil, role:)
      @list = list
      @inviter = inviter
      @user_identifier = user_identifier.to_s.strip.presence
      @friend_id = friend_id
      @role = role.to_s.downcase.strip.presence || "viewer"
    end

    def call!
      validate_inputs!
      target_user = find_target_user!
      validate_membership!(target_user)
      create_membership!(target_user)
    end

    private

    def validate_inputs!
      raise BadRequest, "user_identifier or friend_id is required" if @user_identifier.blank? && @friend_id.blank?
      raise BadRequest, "Invalid role" unless ALLOWED_ROLES.include?(@role)
    end

    def find_target_user!
      if @friend_id.present?
        find_by_friend_id!
      else
        find_by_identifier!
      end
    end

    def find_by_friend_id!
      user = User.find_by(id: @friend_id)
      raise NotFound, "User not found" unless user
      raise Forbidden, "You can only add friends to lists" unless Friendship.friends?(@inviter, user)
      user
    end

    def find_by_identifier!
      user = UserFinder.find_by_identifier(@user_identifier)
      raise NotFound, "User not found" unless user
      user
    end

    def validate_membership!(target_user)
      raise Conflict, "Cannot invite yourself" if target_user.id == @inviter.id
      raise Conflict, "User is already a member of this list" if @list.memberships.exists?(user_id: target_user.id)
    end

    def create_membership!(target_user)
      @list.memberships.create!(user: target_user, role: @role)
    end
  end
end
