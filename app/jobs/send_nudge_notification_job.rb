# frozen_string_literal: true

class SendNudgeNotificationJob < ApplicationJob
  queue_as :default

  def perform(nudge_id:)
    nudge = Nudge.find_by(id: nudge_id)
    return unless nudge

    PushNotifications::Sender.send_nudge(
      from_user: nudge.from_user,
      to_user: nudge.to_user,
      task: nudge.task
    )
  end
end
