# frozen_string_literal: true

class RecurringTaskInstanceJob < ApplicationJob
  queue_as :default

  def perform(user_id:, task_id:)
    user = User.find_by(id: user_id)
    task = Task.find_by(id: task_id)

    return unless user && task
    return unless task.template_id.present?
    return unless task.template&.is_template && task.template&.template_type == "recurring"

    RecurringTaskService.new(user).generate_next_instance(task)
  end
end
