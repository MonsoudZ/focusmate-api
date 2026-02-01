# frozen_string_literal: true

class SubtaskCreationService < ApplicationService
  def initialize(parent_task:, user:, params:)
    @parent_task = parent_task
    @user = user
    @params = params
  end

  def call!
    next_position = (@parent_task.subtasks.where(deleted_at: nil).maximum(:position) || 0) + 1

    subtask = @parent_task.list.tasks.new(
      title: @params[:title],
      note: @params[:note],
      parent_task: @parent_task,
      creator: @user,
      due_at: @parent_task.due_at,
      strict_mode: @parent_task.strict_mode,
      status: :pending,
      position: next_position
    )
    subtask.save!
    subtask
  end
end
