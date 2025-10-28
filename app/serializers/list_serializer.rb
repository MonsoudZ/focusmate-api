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
      user: UserSerializer.new(list.user).as_json,
      role: role_for_current_user,
      shared_with_coaches: shared_coaches,
      tasks_count: tasks_count,
      overdue_tasks_count: overdue_tasks_count,
      created_at: list.created_at.iso8601,
      updated_at: list.updated_at.iso8601
    }.tap do |hash|
      if options[:include_tasks]
        hash[:tasks] = list.tasks_visible_to(current_user).map do |task|
          TaskSerializer.new(task, current_user: current_user).as_json
        end
      end
    end
  end

  private

  def role_for_current_user
    if list.user == current_user
      "owner"
    elsif current_user.coach? && list.shared_with?(current_user)
      "coach"
    else
      "viewer"
    end
  end

  def shared_coaches
    return [] unless list.user == current_user

    list.coaches.map { |coach| UserSerializer.new(coach).as_json }
  end

  def tasks_count
    list.tasks_visible_to(current_user).count
  end

  def overdue_tasks_count
    list.tasks_visible_to(current_user).overdue.count
  end
end
