# frozen_string_literal: true

class Nudge < ApplicationRecord
  belongs_to :task
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"

  validates :task, presence: true
  validates :from_user, presence: true
  validates :to_user, presence: true

  # Prevent spam - limit nudges per task per user
  validate :rate_limit_nudges

  scope :recent, -> { where("created_at > ?", 24.hours.ago) }

  private

  def rate_limit_nudges
    recent_nudges = Nudge.where(
      task: task,
      from_user: from_user,
      created_at: 1.hour.ago..
    ).count

    if recent_nudges >= 3
      errors.add(:base, "You can only nudge about this task 3 times per hour")
    end
  end
end
