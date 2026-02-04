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
    timestamp = Time.current

    ActiveRecord::Base.transaction do
      # Serialize reorders per list to avoid interleaved position writes
      @list.with_lock do
        tasks = @list.tasks.where(id: task_ids).index_by(&:id)

        # Verify all tasks were found
        raise ActiveRecord::RecordNotFound, "Some tasks not found in list" if tasks.size != task_ids.size

        # Lightweight updates while still touching updated_at for sync clients
        @task_positions.each do |entry|
          tasks[entry[:id]].update_columns(position: entry[:position], updated_at: timestamp)
        end
      end
    end
  end

  private

  def validate_positions!
    task_ids = []
    positions = []

    @task_positions.each do |entry|
      task_id = entry[:id]
      position = entry[:position]

      unless task_id.is_a?(Integer) && task_id.positive?
        raise ApplicationError::BadRequest.new(
          "Invalid task id: must be a positive integer",
          code: "invalid_task_id"
        )
      end

      unless position.is_a?(Integer) && position >= 0
        raise ApplicationError::BadRequest.new(
          "Invalid position value: must be a non-negative integer",
          code: "invalid_position"
        )
      end

      task_ids << task_id
      positions << position
    end

    if task_ids.uniq.size != task_ids.size
      raise ApplicationError::BadRequest.new(
        "Duplicate task ids are not allowed",
        code: "duplicate_task_ids"
      )
    end

    if positions.uniq.size != positions.size
      raise ApplicationError::BadRequest.new(
        "Duplicate positions are not allowed",
        code: "duplicate_positions"
      )
    end
  end
end
