# frozen_string_literal: true

module Permissions
  # Centralized permission checking for Task access control.
  # Builds on ListPermissions for list-level access.
  #
  # @example Basic usage
  #   permissions = Permissions::TaskPermissions.new(task, user)
  #   permissions.can_view?   # => true/false
  #   permissions.can_edit?   # => true/false
  #
  # @example Class method shortcuts
  #   Permissions::TaskPermissions.can_edit?(task, user)
  #
  class TaskPermissions
    attr_reader :task, :user

    def initialize(task, user)
      @task = task
      @user = user
      @list_permissions = nil
    end

    # User can view the task
    def can_view?
      return false if user.nil? || task.nil?
      return false if task.deleted?
      return false if task.list.nil?

      list_permissions.can_view?
    end

    # User can edit the task (owner, creator, or list editor)
    def can_edit?
      return false if user.nil? || task.nil?
      return false if task.deleted?
      return false if task.list.nil?

      # List owner can always edit
      return true if list_permissions.owner?

      # Task creator can edit
      return true if creator?

      # List editors can edit
      list_permissions.editor?
    end

    # User can delete the task (same as edit)
    def can_delete?
      can_edit?
    end

    # User can complete the task
    def can_complete?
      can_edit?
    end

    # User can assign the task
    def can_assign?
      can_edit?
    end

    # User can send a nudge for this task
    def can_nudge?
      return false if user.nil? || task.nil?
      return false if task.deleted?

      # Can nudge if you have access to the list
      list_permissions.can_view?
    end

    # User is the task creator
    def creator?
      return false if user.nil? || task.nil?

      task.creator_id == user.id
    end

    # User is assigned to the task
    def assigned?
      return false if user.nil? || task.nil?

      task.assigned_to_id == user.id
    end

    # Class method shortcuts
    class << self
      def can_view?(task, user)
        new(task, user).can_view?
      end

      def can_edit?(task, user)
        new(task, user).can_edit?
      end

      def can_delete?(task, user)
        new(task, user).can_delete?
      end

      def can_nudge?(task, user)
        new(task, user).can_nudge?
      end

      def creator?(task, user)
        new(task, user).creator?
      end
    end

    private

    def list_permissions
      @list_permissions ||= ListPermissions.new(task.list, user)
    end
  end
end
