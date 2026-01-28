# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsTracker do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe ".task_created" do
    it "creates an AnalyticsEvent with event_type task_created" do
      expect {
        described_class.task_created(task, user)
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_created")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
      expect(event.list).to eq(list)
      expect(event.occurred_at).to be_present
    end

    it "includes priority, starred, has_due_date, and due_in_hours in metadata" do
      described_class.task_created(task, user)

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "priority" => task.priority,
        "starred" => task.starred,
        "has_due_date" => true
      )
      expect(event.metadata).to have_key("due_in_hours")
    end

    it "sets due_in_hours to nil when task has no due_at" do
      task_without_due = create(:task, list: list, creator: user, due_at: nil, parent_task: task)

      described_class.task_created(task_without_due, user)

      event = AnalyticsEvent.last
      expect(event.metadata["has_due_date"]).to be false
      expect(event.metadata["due_in_hours"]).to be_nil
    end
  end

  describe ".task_completed" do
    it "creates an AnalyticsEvent with event_type task_completed" do
      expect {
        described_class.task_completed(task, user, was_overdue: false)
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_completed")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
    end

    it "includes overdue info in metadata" do
      described_class.task_completed(task, user, was_overdue: true, minutes_overdue: 45, missed_reason: "forgot")

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "was_overdue" => true,
        "minutes_overdue" => 45,
        "missed_reason" => "forgot"
      )
    end

    it "includes time_to_complete_hours, completed_day_of_week, and completed_hour" do
      freeze_time do
        described_class.task_completed(task, user, was_overdue: false)

        event = AnalyticsEvent.last
        expect(event.metadata).to have_key("time_to_complete_hours")
        expect(event.metadata["completed_day_of_week"]).to eq(Time.current.strftime("%A"))
        expect(event.metadata["completed_hour"]).to eq(Time.current.hour)
      end
    end
  end

  describe ".task_deleted" do
    it "creates an AnalyticsEvent with event_type task_deleted" do
      expect {
        described_class.task_deleted(task, user)
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_deleted")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
    end

    it "includes was_completed, was_overdue, and age_hours in metadata" do
      described_class.task_deleted(task, user)

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "was_completed" => false,
        "was_overdue" => false
      )
      expect(event.metadata).to have_key("age_hours")
    end
  end

  describe ".list_created" do
    it "creates an AnalyticsEvent with event_type list_created" do
      expect {
        described_class.list_created(list, user)
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("list_created")
      expect(event.user).to eq(user)
      expect(event.list).to eq(list)
      expect(event.task).to be_nil
    end

    it "includes visibility in metadata" do
      described_class.list_created(list, user)

      event = AnalyticsEvent.last
      expect(event.metadata).to include("visibility" => list.visibility)
    end
  end

  describe ".list_shared" do
    let(:shared_with_user) { create(:user) }

    it "creates an AnalyticsEvent with event_type list_shared" do
      expect {
        described_class.list_shared(list, user, shared_with: shared_with_user, role: "editor")
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("list_shared")
      expect(event.user).to eq(user)
      expect(event.list).to eq(list)
    end

    it "includes shared_with_user_id and role in metadata" do
      described_class.list_shared(list, user, shared_with: shared_with_user, role: "viewer")

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "shared_with_user_id" => shared_with_user.id,
        "role" => "viewer"
      )
    end
  end

  describe ".app_opened" do
    it "creates an AnalyticsEvent with event_type app_opened" do
      expect {
        described_class.app_opened(user, platform: "ios")
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("app_opened")
      expect(event.user).to eq(user)
      expect(event.task).to be_nil
      expect(event.list).to be_nil
    end

    it "includes platform and version in metadata" do
      described_class.app_opened(user, platform: "ios", version: "2.1.0")

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "platform" => "ios",
        "version" => "2.1.0"
      )
    end

    it "includes day_of_week and hour in metadata" do
      freeze_time do
        described_class.app_opened(user, platform: "android")

        event = AnalyticsEvent.last
        expect(event.metadata["day_of_week"]).to eq(Time.current.strftime("%A"))
        expect(event.metadata["hour"]).to eq(Time.current.hour)
      end
    end
  end

  describe "error handling" do
    it "does not raise when AnalyticsEvent.create! fails" do
      allow(AnalyticsEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)

      expect {
        described_class.app_opened(user, platform: "ios")
      }.not_to raise_error
    end

    it "logs the error when creation fails" do
      allow(AnalyticsEvent).to receive(:create!).and_raise(StandardError.new("db connection lost"))

      expect(Rails.logger).to receive(:error).with(/AnalyticsTracker failed: db connection lost/)

      described_class.task_created(task, user)
    end
  end
end
