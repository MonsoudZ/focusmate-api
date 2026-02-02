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
      tasks_count: list.parent_tasks_count,
      completed_tasks_count: completed_tasks_count,
      overdue_tasks_count: overdue_tasks_count,
      members: serialize_members,
      created_at: list.created_at,
      updated_at: list.updated_at
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

  # Memoized task counts - single query for both completed and overdue
  def task_counts
    @task_counts ||= if list.tasks.loaded?
                       compute_counts_from_loaded_tasks
                     else
                       fetch_counts_from_db
                     end
  end

  def completed_tasks_count
    task_counts[:completed]
  end

  def overdue_tasks_count
    task_counts[:overdue]
  end

  def compute_counts_from_loaded_tasks
    now = Time.current
    parent_tasks = list.tasks.reject { |t| t.deleted_at.present? || t.parent_task_id.present? }

    completed = parent_tasks.count { |t| t.status == "done" }
    overdue = parent_tasks.count { |t| t.due_at.present? && t.due_at < now && t.status != "done" }

    { completed: completed, overdue: overdue }
  end

  def fetch_counts_from_db
    done_status = Task.statuses[:done]

    result = base_tasks_scope.pick(
      Arel.sql("COUNT(CASE WHEN status = #{done_status} THEN 1 END)"),
      Arel.sql("COUNT(CASE WHEN due_at IS NOT NULL AND due_at < NOW() AND status != #{done_status} THEN 1 END)")
    )

    { completed: result[0].to_i, overdue: result[1].to_i }
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
