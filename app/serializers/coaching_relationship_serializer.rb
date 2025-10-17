class CoachingRelationshipSerializer
  def initialize(relationship, current_user:)
    @relationship = relationship
    @current_user = current_user
  end

  def as_json
    {
      id: @relationship.id,
      status: @relationship.status,
      invited_by: @relationship.invited_by,
      accepted_at: @relationship.accepted_at,
      created_at: @relationship.created_at,
      updated_at: @relationship.updated_at,
      coach: coach_data,
      client: client_data,
      preferences: preferences_data,
      stats: stats_data
    }
  end

  private

  def coach_data
    {
      id: @relationship.coach.id,
      email: @relationship.coach.email,
      name: @relationship.coach.name,
      role: @relationship.coach.role
    }
  end

  def client_data
    {
      id: @relationship.client.id,
      email: @relationship.client.email,
      name: @relationship.client.name,
      role: @relationship.client.role
    }
  end

  def preferences_data
    {
      notify_on_completion: @relationship.notify_on_completion,
      notify_on_missed_deadline: @relationship.notify_on_missed_deadline,
      send_daily_summary: @relationship.send_daily_summary,
      daily_summary_time: @relationship.daily_summary_time
    }
  end

  def stats_data
    {
      total_tasks: @relationship.all_tasks.count,
      completed_tasks: @relationship.all_tasks.where(status: :done).count,
      overdue_tasks: @relationship.overdue_tasks.count,
      tasks_requiring_explanation: @relationship.tasks_requiring_explanation.count,
      shared_lists: @relationship.lists.count
    }
  end
end
