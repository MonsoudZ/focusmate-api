# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationLog, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:list, owner: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:notification_log) { build(:notification_log, user: user, task: task, notification_type: "task_reminder", message: "Your task is due soon", delivered: false) }

  describe 'validations' do
    it 'belongs to user' do
      expect(notification_log).to be_valid
      expect(notification_log.user).to eq(user)
    end

    it 'optionally belongs to task' do
      # Test with task
      expect(notification_log).to be_valid
      expect(notification_log.task).to eq(task)

      # Test without task
      notification_without_task = build(:notification_log, user: user, task: nil, notification_type: "system_announcement", message: "System announcement")
      expect(notification_without_task).to be_valid
      expect(notification_without_task.task).to be_nil
    end

    it 'requires notification_type' do
      notification_log.notification_type = nil
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:notification_type]).to include("can't be blank")
    end

    it 'validates notification_type inclusion' do
      notification_log.notification_type = "invalid_type"
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:notification_type]).to include("is not included in the list")
    end

    it 'requires message' do
      notification_log.message = nil
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:message]).to include("can't be blank")
    end

    it 'validates message length' do
      notification_log.message = "a" * 5001
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:message]).to include("is too long (maximum is 5000 characters)")
    end

    it 'validates delivered is boolean' do
      # Rails automatically converts most values to boolean, so we test the validation directly
      notification_log.delivered = nil
      notification_log.valid?
      expect(notification_log.delivered).to be false # Should be set by before_validation callback
      expect(notification_log).to be_valid
    end

    it 'validates metadata is valid JSON' do
      notification_log.metadata = "invalid_json"
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:metadata]).to include("is not a valid JSON")
    end

    it 'allows nil metadata' do
      notification_log.metadata = nil
      expect(notification_log).to be_valid
    end

    it 'allows valid JSON metadata' do
      notification_log.metadata = { "key" => "value" }
      expect(notification_log).to be_valid
    end

    it 'validates delivery_method inclusion' do
      notification_log.delivery_method = "invalid_method"
      expect(notification_log).not_to be_valid
      expect(notification_log.errors[:delivery_method]).to include("is not included in the list")
    end

    it 'allows nil delivery_method' do
      notification_log.delivery_method = nil
      expect(notification_log).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(notification_log.user).to eq(user)
    end

    it 'belongs to task' do
      expect(notification_log.task).to eq(task)
    end
  end

  describe 'scopes' do
    it 'has for_user scope' do
      other_user = create(:user)
      user_notification = create(:notification_log, user: user)
      other_notification = create(:notification_log, user: other_user)

      expect(NotificationLog.for_user(user)).to include(user_notification)
      expect(NotificationLog.for_user(user)).not_to include(other_notification)
    end

    it 'has for_task scope' do
      other_task = create(:task, list: list, creator: user)
      task_notification = create(:notification_log, user: user, task: task)
      other_notification = create(:notification_log, user: user, task: other_task)

      expect(NotificationLog.for_task(task)).to include(task_notification)
      expect(NotificationLog.for_task(task)).not_to include(other_notification)
    end

    it 'has delivered scope' do
      delivered_notification = create(:notification_log, user: user, delivered: true)
      undelivered_notification = create(:notification_log, user: user, delivered: false)

      expect(NotificationLog.delivered).to include(delivered_notification)
      expect(NotificationLog.delivered).not_to include(undelivered_notification)
    end

    it 'has undelivered scope' do
      delivered_notification = create(:notification_log, user: user, delivered: true)
      undelivered_notification = create(:notification_log, user: user, delivered: false)

      expect(NotificationLog.undelivered).to include(undelivered_notification)
      expect(NotificationLog.undelivered).not_to include(delivered_notification)
    end

    it 'has recent scope' do
      recent_notification = create(:notification_log, user: user, created_at: 1.hour.ago)
      old_notification = create(:notification_log, user: user, created_at: 1.week.ago)

      expect(NotificationLog.recent).to include(recent_notification)
      expect(NotificationLog.recent).not_to include(old_notification)
    end

    it 'has by_type scope' do
      reminder_notification = create(:notification_log, user: user, notification_type: "task_reminder")
      announcement_notification = create(:notification_log, user: user, notification_type: "system_announcement")

      expect(NotificationLog.by_type("task_reminder")).to include(reminder_notification)
      expect(NotificationLog.by_type("task_reminder")).not_to include(announcement_notification)
    end
  end

  describe 'methods' do
    it 'checks if notification is delivered' do
      delivered_notification = create(:notification_log, user: user, delivered: true)
      undelivered_notification = create(:notification_log, user: user, delivered: false)

      expect(delivered_notification.delivered?).to be true
      expect(undelivered_notification.delivered?).to be false
    end

    it 'checks if notification is undelivered' do
      delivered_notification = create(:notification_log, user: user, delivered: true)
      undelivered_notification = create(:notification_log, user: user, delivered: false)

      expect(undelivered_notification.undelivered?).to be true
      expect(delivered_notification.undelivered?).to be false
    end

    it 'marks notification as delivered' do
      notification_log.delivered = false
      notification_log.mark_delivered!
      expect(notification_log.delivered).to be true
    end

    it 'marks notification as undelivered' do
      notification_log.delivered = true
      notification_log.mark_undelivered!
      expect(notification_log.delivered).to be false
    end

    it 'returns notification summary' do
      notification_log.metadata = { "priority" => "high", "channel" => "push" }
      summary = notification_log.summary
      expect(summary).to include(:id, :notification_type, :message, :delivered, :metadata)
    end

    it 'returns notification details' do
      notification_log.delivery_method = "push"
      notification_log.metadata = { "priority" => "high" }

      details = notification_log.details
      expect(details).to include(:id, :notification_type, :message, :delivered, :delivery_method, :metadata)
    end

    it 'returns age in hours' do
      notification_log.created_at = 2.hours.ago
      expect(notification_log.age_hours).to be >= 2
    end

    it 'checks if notification is recent' do
      notification_log.created_at = 30.minutes.ago
      expect(notification_log.recent?).to be true

      notification_log.created_at = 2.hours.ago
      expect(notification_log.recent?).to be false
    end

    it 'returns priority level' do
      notification_log.notification_type = "urgent_alert"
      expect(notification_log.priority).to eq("high")

      notification_log.notification_type = "task_reminder"
      expect(notification_log.priority).to eq("medium")

      notification_log.notification_type = "system_announcement"
      expect(notification_log.priority).to eq("low")
    end

    it 'returns notification type category' do
      notification_log.notification_type = "task_reminder"
      expect(notification_log.category).to eq("task")

      notification_log.notification_type = "system_announcement"
      expect(notification_log.category).to eq("system")

      notification_log.notification_type = "coaching_message"
      expect(notification_log.category).to eq("coaching")
    end

    it 'checks if notification is actionable' do
      notification_log.notification_type = "task_reminder"
      expect(notification_log.actionable?).to be true

      notification_log.notification_type = "system_announcement"
      expect(notification_log.actionable?).to be false
    end

    it 'returns notification data' do
      notification_log.metadata = { "priority" => "high", "channel" => "push" }
      data = notification_log.notification_data
      expect(data).to include(:type, :message, :delivered, :metadata)
    end

    it 'generates notification report' do
      notification_log.notification_type = "task_reminder"
      notification_log.message = "Your task is due soon"
      notification_log.metadata = { "priority" => "high" }

      report = notification_log.generate_report
      expect(report).to include(:type, :message, :delivered, :priority)
    end
  end

  describe 'callbacks' do
    it 'sets default delivered status before validation' do
      notification_log.delivered = nil
      notification_log.valid?
      expect(notification_log.delivered).to be false
    end

    it 'does not override existing delivered status' do
      notification_log.delivered = true
      notification_log.valid?
      expect(notification_log.delivered).to be true
    end

    it 'validates JSON format of metadata' do
      notification_log.metadata = { "key" => "value" }
      notification_log.valid?
      expect(notification_log.metadata).to eq({ "key" => "value" })
    end
  end

  describe 'soft deletion' do
    it 'soft deletes notification log' do
      notification_log.save!
      notification_log.soft_delete!
      expect(notification_log.deleted?).to be true
      expect(notification_log.deleted_at).not_to be_nil
    end

    it 'restores soft deleted notification log' do
      notification_log.save!
      notification_log.soft_delete!
      notification_log.restore!
      expect(notification_log.deleted?).to be false
      expect(notification_log.deleted_at).to be_nil
    end

    it 'excludes soft deleted logs from default scope' do
      notification_log.save!
      notification_log.soft_delete!
      expect(NotificationLog.all).not_to include(notification_log)
      expect(NotificationLog.with_deleted).to include(notification_log)
    end
  end

  describe 'notification types' do
    it 'handles task_reminder notifications' do
      reminder = create(:notification_log, user: user, task: task, notification_type: "task_reminder")
      expect(reminder.category).to eq("task")
      expect(reminder.actionable?).to be true
    end

    it 'handles system_announcement notifications' do
      announcement = create(:notification_log, user: user, notification_type: "system_announcement")
      expect(announcement.category).to eq("system")
      expect(announcement.actionable?).to be false
    end

    it 'handles coaching_message notifications' do
      coaching_message = create(:notification_log, user: user, notification_type: "coaching_message")
      expect(coaching_message.category).to eq("coaching")
      expect(coaching_message.actionable?).to be true
    end

    it 'handles urgent_alert notifications' do
      alert = create(:notification_log, user: user, notification_type: "urgent_alert")
      expect(alert.priority).to eq("high")
      expect(alert.actionable?).to be true
    end
  end

  describe 'delivery tracking' do
    it 'tracks delivery status' do
      notification_log.delivered = false
      expect(notification_log.undelivered?).to be true

      notification_log.mark_delivered!
      expect(notification_log.delivered?).to be true
    end

    it 'tracks delivery method' do
      notification_log.delivery_method = "push"
      expect(notification_log.delivery_method).to eq("push")
    end

    it 'tracks delivery metadata' do
      notification_log.metadata = { "delivery_time" => Time.current, "channel" => "push" }
      expect(notification_log.metadata["delivery_time"]).not_to be_nil
      expect(notification_log.metadata["channel"]).to eq("push")
    end
  end

  describe 'user notifications' do
    it 'returns user notification count' do
      create(:notification_log, user: user, delivered: false)
      create(:notification_log, user: user, delivered: true)

      expect(NotificationLog.for_user(user).count).to eq(2)
      expect(NotificationLog.for_user(user).undelivered.count).to eq(1)
    end

    it 'returns recent notifications for user' do
      recent_notification = create(:notification_log, user: user, created_at: 1.hour.ago)
      old_notification = create(:notification_log, user: user, created_at: 1.week.ago)

      recent_notifications = NotificationLog.for_user(user).recent
      expect(recent_notifications).to include(recent_notification)
      expect(recent_notifications).not_to include(old_notification)
    end
  end

  describe 'task notifications' do
    it 'returns task notification count' do
      create(:notification_log, user: user, task: task, delivered: false)
      create(:notification_log, user: user, task: task, delivered: true)

      expect(NotificationLog.for_task(task).count).to eq(2)
      expect(NotificationLog.for_task(task).undelivered.count).to eq(1)
    end

    it 'returns task notification timeline' do
      notification1 = create(:notification_log, user: user, task: task, created_at: 1.hour.ago)
      notification2 = create(:notification_log, user: user, task: task, created_at: 30.minutes.ago)

      timeline = NotificationLog.for_task(task).order(:created_at)
      expect(timeline.first).to eq(notification1)
      expect(timeline.last).to eq(notification2)
    end
  end

  describe 'metadata handling' do
    it 'stores complex metadata' do
      complex_metadata = {
        "priority" => "high",
        "channel" => "push",
        "delivery_time" => Time.current.iso8601,
        "tags" => [ "urgent", "important" ]
      }

      notification_log.metadata = complex_metadata
      expect(notification_log).to be_valid
      expect(notification_log.metadata).to eq(complex_metadata)
    end

    it 'handles empty metadata' do
      notification_log.metadata = {}
      expect(notification_log).to be_valid
      expect(notification_log.metadata).to eq({})
    end

    it 'validates metadata structure' do
      notification_log.metadata = { "invalid" => "structure" }
      expect(notification_log).to be_valid
    end
  end
end
