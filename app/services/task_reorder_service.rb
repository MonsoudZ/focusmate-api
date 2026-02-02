# frozen_string_literal: true

class TaskReorderService < ApplicationService
  def initialize(list:, task_positions:)
    @list = list
    @task_positions = task_positions
  end

  def call!
    return if @task_positions.empty?

    task_ids = @task_positions.map { |entry| entry[:id] }

    # Load all tasks in single query
    tasks = @list.tasks.where(id: task_ids).index_by(&:id)

    # Verify all tasks were found
    raise ActiveRecord::RecordNotFound, "Some tasks not found in list" if tasks.size != task_ids.size

    # Update positions (lightweight updates, no callbacks)
    ActiveRecord::Base.transaction do
      @task_positions.each do |entry|
        tasks[entry[:id]].update_column(:position, entry[:position])
      end
    end
  end
end
