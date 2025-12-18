# frozen_string_literal: true

module Notifications
  class TaskNudge
    Result = Struct.new(:sent, :failed, :skipped, keyword_init: true)

    def self.call!(task_id:, reason:, options:)
      new(task_id:, reason:, options:).call!
    end

    def initialize(task_id:, reason:, options:)
      @task_id = Integer(task_id)
      @reason = reason.presence
      @options = options.is_a?(Hash) ? options : {}
    end

    def call!
      task = Task.includes(:list).find(@task_id)
      list = task.list

      members = list.memberships
                    .includes(:user)
                    .joins(:user)
                    .where(users: { active: true })
                    .map(&:user)

      return Result.new(sent: 0, failed: 0, skipped: 0) if members.empty?

      payload = Notifications::Payloads::TaskNudge.build(task: task, reason: @reason, options: @options)

      stats = { sent: 0, failed: 0, skipped: 0 }

      members.each do |user|
        unless should_send_to_user?(user, task)
          stats[:skipped] += 1
          next
        end

        delivery = Notifications::ApnsDelivery.call(user: user, payload: payload)

        stats[:sent]    += delivery.sent
        stats[:failed]  += delivery.failed
        stats[:skipped] += delivery.skipped
      end

      Result.new(**stats)
    end

    private

    def should_send_to_user?(user, task)
      return false unless user.respond_to?(:active?) ? user.active? : true

      # optional preference gate
      if user.respond_to?(:preferences) && user.preferences.is_a?(Hash)
        enabled = user.preferences.dig("notifications", "enabled")
        return false if enabled == false
      end

      # optional skip creator
      if @options[:skip_creator] && task.respond_to?(:creator_id)
        return false if task.creator_id == user.id
      end

      # optional visibility gate
      if task.respond_to?(:visible_to?)
        return false unless task.visible_to?(user)
      end

      true
    end
  end
end
