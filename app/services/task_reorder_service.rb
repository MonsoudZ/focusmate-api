# frozen_string_literal: true

class TaskReorderService
  def self.call!(list:, task_positions:)
    new(list:).call!(task_positions)
  end

  def initialize(list:)
    @list = list
  end

  def call!(task_positions)
    ActiveRecord::Base.transaction do
      task_positions.each do |entry|
        task = @list.tasks.find(entry[:id])
        task.update!(position: entry[:position])
      end
    end
  end
end
