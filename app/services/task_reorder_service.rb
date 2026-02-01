# frozen_string_literal: true

class TaskReorderService < ApplicationService
  def initialize(list:, task_positions:)
    @list = list
    @task_positions = task_positions
  end

  def call!
    ActiveRecord::Base.transaction do
      @task_positions.each do |entry|
        task = @list.tasks.find(entry[:id])
        task.update!(position: entry[:position])
      end
    end
  end
end
