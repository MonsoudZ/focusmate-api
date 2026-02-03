# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskReminderJob, type: :job do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  before do
    allow(PushNotifications::Sender).to receive(:send_task_reminder)
  end

  describe "#perform" do
    context "with a task due soon" do
      it "sends reminder for task due within notification interval" do
        task = create(:task, list: list, creator: user, due_at: 5.minutes.from_now, notification_interval_minutes: 10)

        described_class.new.perform

        expect(PushNotifications::Sender).to have_received(:send_task_reminder).with(
          to_user: user,
          task: task
        )
      end

      it "updates reminder_sent_at after sending" do
        task = create(:task, list: list, creator: user, due_at: 5.minutes.from_now)

        expect {
          described_class.new.perform
        }.to change { task.reload.reminder_sent_at }.from(nil)
      end

      it "sends to assignee if task is assigned" do
        assignee = create(:user)
        create(:membership, list: list, user: assignee, role: "editor")
        task = create(:task, list: list, creator: user, assigned_to: assignee, due_at: 5.minutes.from_now)

        described_class.new.perform

        expect(PushNotifications::Sender).to have_received(:send_task_reminder).with(
          to_user: assignee,
          task: task
        )
      end
    end

    context "with tasks that should not receive reminders" do
      it "skips completed tasks" do
        create(:task, list: list, creator: user, due_at: 5.minutes.from_now, status: :done)

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end

      it "skips tasks due beyond notification interval" do
        create(:task, list: list, creator: user, due_at: 20.minutes.from_now, notification_interval_minutes: 10)

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end

      it "skips tasks that already received a reminder" do
        create(:task, list: list, creator: user, due_at: 5.minutes.from_now, reminder_sent_at: 1.minute.ago)

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end

      it "skips deleted tasks" do
        task = create(:task, list: list, creator: user, due_at: 5.minutes.from_now)
        task.soft_delete!

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end

      it "skips template tasks" do
        create(:task, list: list, creator: user, due_at: 5.minutes.from_now, is_template: true)

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end

      it "skips overdue tasks" do
        create(:task, list: list, creator: user, due_at: 5.minutes.ago)

        described_class.new.perform

        expect(PushNotifications::Sender).not_to have_received(:send_task_reminder)
      end
    end

    context "with multiple tasks" do
      it "sends reminders for all eligible tasks" do
        task1 = create(:task, list: list, creator: user, due_at: 5.minutes.from_now)
        task2 = create(:task, list: list, creator: user, due_at: 8.minutes.from_now)

        described_class.new.perform

        expect(PushNotifications::Sender).to have_received(:send_task_reminder).twice
      end
    end

    context "error handling" do
      it "continues processing if one task fails" do
        task1 = create(:task, list: list, creator: user, due_at: 5.minutes.from_now)
        task2 = create(:task, list: list, creator: user, due_at: 8.minutes.from_now)

        call_count = 0
        allow(PushNotifications::Sender).to receive(:send_task_reminder) do
          call_count += 1
          raise "Error" if call_count == 1
        end

        described_class.new.perform

        expect(PushNotifications::Sender).to have_received(:send_task_reminder).twice
      end
    end
  end
end
