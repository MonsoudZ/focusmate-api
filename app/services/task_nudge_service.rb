# frozen_string_literal: true

class TaskNudgeService < ApplicationService
  def initialize(task:, from_user:)
    @task = task
    @from_user = from_user
  end

  def call!
    to_user = @task.creator || @task.list.user

    if to_user.id == @from_user.id
      raise ApplicationError::UnprocessableEntity.new("You cannot nudge yourself", code: "self_nudge")
    end

    nudge = Nudge.new(task: @task, from_user: @from_user, to_user: to_user)
    nudge.save!

    PushNotifications::Sender.send_nudge(
      from_user: @from_user,
      to_user: to_user,
      task: @task
    )

    nudge
  end
end
