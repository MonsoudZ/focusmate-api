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
end