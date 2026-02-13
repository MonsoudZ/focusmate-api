# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  NOTIFICATION_TYPES = %i[nudge task_assigned list_joined task_reminder].freeze

  belongs_to :user

  validates :user, uniqueness: true
  NOTIFICATION_TYPES.each do |type|
    validates :"#{type}_enabled", inclusion: { in: [ true, false ] }
  end

  # Returns whether a specific notification type is enabled.
  def enabled_for?(type)
    send(:"#{type}_enabled")
  end

  # Returns whether notifications of the given type are enabled for a user.
  # Returns true if no preference record exists (opt-out model).
  def self.enabled_for_user?(user, type)
    pref = find_by(user: user)
    return true unless pref

    pref.enabled_for?(type)
  end
end
