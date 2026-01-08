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
        hash[:tasks] = list.tasks.map do |task|
          TaskSerializer.new(task, current_user: current_user).as_json
        end
      end
    end
  end

  private

  def role_for_current_user
    if list.user_id == current_user.id
      "owner"
    elsif list.memberships.exists?(user_id: current_user.id, role: "editor")
      "editor"
    elsif list.memberships.exists?(user_id: current_user.id)
      "viewer"
    else
      nil
    end
  end
end
