# frozen_string_literal: true

class ListSerializer
  attr_reader :list, :current_user, :options

  def initialize(list, current_user:, **options)
    @list = list
    @current_user = current_user
    @options = options
  end

  def as_json
    {
      id: list.id,
      name: list.name,
      description: list.description,
      visibility: list.visibility,
      color: list.color || "blue",
      user: UserSerializer.one(list.user),
      role: role_for_current_user,
      tasks_count: list.tasks_count,
      completed_tasks_count: completed_tasks_count,
      overdue_tasks_count: overdue_tasks_count,
      members: serialize_members,
      created_at: list.created_at.iso8601,
      updated_at: list.updated_at.iso8601
    }.tap do |hash|
      if options[:include_tasks]
        hash[:tasks] = list.tasks.includes(:tags, :creator, :subtasks, list: :user).map do |task|
          TaskSerializer.new(task, current_user: current_user).as_json
        end
      end
    end
  end

  private

  def role_for_current_user
    return "owner" if list.user_id == current_user.id

    # Use loaded association if available to avoid N+1
    membership = if list.memberships.loaded?
                   list.memberships.find { |m| m.user_id == current_user.id }
    else
                   list.memberships.find_by(user_id: current_user.id)
    end

    return nil unless membership
    membership.role == "editor" ? "editor" : "viewer"
  end

  def base_tasks_scope
    list.tasks.where(deleted_at: nil, parent_task_id: nil)
  end

  def completed_tasks_count
    if list.tasks.loaded?
      list.tasks.reject(&:deleted?).count { |t| t.parent_task_id.nil? && t.status == "done" }
    else
      base_tasks_scope.where(status: "done").count
    end
  end

  def overdue_tasks_count
    if list.tasks.loaded?
      now = Time.current
      list.tasks.reject(&:deleted?).count do |t|
        t.parent_task_id.nil? &&
          t.due_at.present? &&
          t.due_at < now &&
          t.status != "done"
      end
    else
      base_tasks_scope
        .where.not(due_at: nil)
        .where("due_at < ?", Time.current)
        .where.not(status: "done")
        .count
    end
  end

  def serialize_members
    members = []

    # Owner first
    members << {
      id: list.user.id,
      name: list.user.name,
      email: list.user.email,
      role: "owner"
    }

    # Then memberships
    memberships = list.memberships.loaded? ? list.memberships : list.memberships.includes(:user)
    memberships.each do |m|
      next unless m.user

      members << {
        id: m.user.id,
        name: m.user.name,
        email: m.user.email,
        role: m.role
      }
    end

    members
  end
end
