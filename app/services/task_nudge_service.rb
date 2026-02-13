# frozen_string_literal: true

class TaskNudgeService < ApplicationService
  RATE_LIMIT_WINDOW = 10.minutes

  def initialize(task:, from_user:)
    @task = task
    @from_user = from_user
  end

  def call!
    recipients = find_recipients

    if recipients.empty?
      raise ApplicationError::UnprocessableEntity.new(
        "No one to nudge - you're the only member of this list",
        code: "no_recipients"
      )
    end

    # Batch rate limit check (1 query instead of N)
    recently_nudged_ids = recent_nudge_recipient_ids
    eligible_recipients = recipients.reject { |r| recently_nudged_ids.include?(r.id) }

    if eligible_recipients.empty?
      raise ApplicationError::UnprocessableEntity.new(
        "You recently nudged everyone about this task. Please wait a few minutes.",
        code: "rate_limited"
      )
    end

    # All-or-nothing: nudge records + notification jobs commit atomically.
    # Solid Queue shares the same DB, so if the transaction rolls back
    # neither the nudges nor the jobs are persisted.
    ActiveRecord::Base.transaction do
      eligible_recipients.map do |recipient|
        nudge = Nudge.create!(task: @task, from_user: @from_user, to_user: recipient)
        SendNudgeNotificationJob.perform_later(nudge_id: nudge.id)
        nudge
      end
    end
  end

  private

  def find_recipients
    list = @task.list

    # Get all list members plus the owner, excluding the sender
    recipient_ids = list.memberships.pluck(:user_id)
    recipient_ids << list.user_id
    recipient_ids.uniq!
    recipient_ids.delete(@from_user.id)

    users = User.where(id: recipient_ids)

    # Hidden tasks can't be nudged to others (only creator can see them)
    users = users.none if @task.private_task?

    users
  end

  def recent_nudge_recipient_ids
    Nudge.where(
      task: @task,
      from_user: @from_user,
      created_at: RATE_LIMIT_WINDOW.ago..Time.current
    ).pluck(:to_user_id)
  end
end
