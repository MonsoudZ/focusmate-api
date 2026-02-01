# frozen_string_literal: true

module Permissions
  # Centralized permission checking for List access control.
  # Use this service instead of duplicating permission logic across models,
  # services, policies, and serializers.
  #
  # @example Basic usage
  #   permissions = Permissions::ListPermissions.new(list, user)
  #   permissions.can_view?   # => true/false
  #   permissions.can_edit?   # => true/false
  #   permissions.owner?      # => true/false
  #
  # @example Class method shortcuts
  #   Permissions::ListPermissions.can_edit?(list, user)
  #   Permissions::ListPermissions.role_for(list, user)
  #
  class ListPermissions
    OWNER_ROLE = "owner"
    EDITOR_ROLE = "editor"
    VIEWER_ROLE = "viewer"
    EDITABLE_ROLES = [ OWNER_ROLE, EDITOR_ROLE ].freeze

    attr_reader :list, :user

    def initialize(list, user)
      @list = list
      @user = user
      @membership = nil
      @membership_loaded = false
    end

    # Returns the user's role for this list
    # @return [String, nil] "owner", "editor", "viewer", or nil
    def role
      return nil if user.nil? || list.nil?
      return OWNER_ROLE if owner?

      membership&.role
    end

    # User owns the list
    def owner?
      return false if user.nil? || list.nil?

      list.user_id == user.id
    end

    # User is an editor (but not owner)
    def editor?
      return false if user.nil? || list.nil?
      return false if owner?

      membership&.role == EDITOR_ROLE
    end

    # User is a viewer (but not owner or editor)
    def viewer?
      return false if user.nil? || list.nil?
      return false if owner?

      membership&.role == VIEWER_ROLE
    end

    # User is a member (any role except owner)
    def member?
      return false if user.nil? || list.nil?

      membership.present?
    end

    # User can view the list (owner or any member)
    def can_view?
      return false if user.nil? || list.nil?
      return false if list.deleted?

      owner? || member?
    end

    # User can edit the list (owner or editor)
    def can_edit?
      return false if user.nil? || list.nil?
      return false if list.deleted?

      owner? || editor?
    end

    # User can delete the list (owner only)
    def can_delete?
      return false if user.nil? || list.nil?

      owner?
    end

    # User can manage memberships (owner only)
    def can_manage_memberships?
      owner?
    end

    # User has any access to the list
    def accessible?
      can_view?
    end

    # Class method shortcuts for convenience
    class << self
      def role_for(list, user)
        new(list, user).role
      end

      def can_view?(list, user)
        new(list, user).can_view?
      end

      def can_edit?(list, user)
        new(list, user).can_edit?
      end

      def can_delete?(list, user)
        new(list, user).can_delete?
      end

      def accessible?(list, user)
        new(list, user).accessible?
      end

      def owner?(list, user)
        new(list, user).owner?
      end

      def member?(list, user)
        new(list, user).member?
      end
    end

    private

    # Lazy load membership to avoid unnecessary queries
    def membership
      return @membership if @membership_loaded

      @membership_loaded = true
      @membership = list.memberships.find_by(user_id: user.id)
    end
  end
end
