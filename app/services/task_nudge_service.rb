# frozen_string_literal: true

class TaskNudgeService
  class Error < StandardError; end
  class SelfNudge < Error; end

  def initialize(task:, from_user:)
    @task = task
    @from_user = from_user
  end

  def call!
    to_user = @task.creator || @task.list.user

    raise SelfNudge, "You cannot nudge yourself" if to_user.id == @from_user.id

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
