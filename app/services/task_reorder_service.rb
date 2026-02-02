# frozen_string_literal: true

class TaskReorderService < ApplicationService
  def initialize(list:, task_positions:)
    @list = list
    @task_positions = task_positions
  end

  def call!
    return if @task_positions.empty?

    validate_positions!

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

  private

  def validate_positions!
    @task_positions.each do |entry|
      position = entry[:position]
      unless position.is_a?(Integer) && position >= 0
        raise ApplicationError::BadRequest.new(
          "Invalid position value: must be a non-negative integer",
          code: "invalid_position"
        )
      end
    end
  end
end
