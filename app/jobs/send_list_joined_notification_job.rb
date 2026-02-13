# frozen_string_literal: true

class SendListJoinedNotificationJob < ApplicationJob
  queue_as :default

  def perform(list_id:, new_member_id:)
    list = List.find_by(id: list_id)
    return unless list

    new_member = User.find_by(id: new_member_id)
    return unless new_member

    PushNotifications::Sender.send_list_joined(
      to_user: list.user,
      new_member: new_member,
      list: list
    )
  end
end
