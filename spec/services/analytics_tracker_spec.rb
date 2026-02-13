# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsTracker do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe ".task_created" do
    it "enqueues an AnalyticsEventJob" do
      expect {
        described_class.task_created(task, user)
      }.to have_enqueued_job(AnalyticsEventJob)
    end

    it "creates an AnalyticsEvent with event_type task_created" do
      expect {
        perform_enqueued_jobs { described_class.task_created(task, user) }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_created")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
      expect(event.list).to eq(list)
      expect(event.occurred_at).to be_present
    end

    it "includes priority, starred, has_due_date, and due_in_hours in metadata" do
      perform_enqueued_jobs { described_class.task_created(task, user) }

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

      perform_enqueued_jobs { described_class.task_created(task_without_due, user) }

      event = AnalyticsEvent.last
      expect(event.metadata["has_due_date"]).to be false
      expect(event.metadata["due_in_hours"]).to be_nil
    end
  end

  describe ".task_completed" do
    it "creates an AnalyticsEvent with event_type task_completed" do
      expect {
        perform_enqueued_jobs { described_class.task_completed(task, user, was_overdue: false) }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_completed")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
    end

    it "includes overdue info in metadata" do
      perform_enqueued_jobs do
        described_class.task_completed(task, user, was_overdue: true, minutes_overdue: 45, missed_reason: "forgot")
      end

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "was_overdue" => true,
        "minutes_overdue" => 45,
        "missed_reason" => "forgot"
      )
    end

    it "includes time_to_complete_hours, completed_day_of_week, and completed_hour" do
      freeze_time do
        perform_enqueued_jobs { described_class.task_completed(task, user, was_overdue: false) }

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
        perform_enqueued_jobs { described_class.task_deleted(task, user) }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("task_deleted")
      expect(event.user).to eq(user)
      expect(event.task).to eq(task)
    end

    it "includes was_completed, was_overdue, and age_hours in metadata" do
      perform_enqueued_jobs { described_class.task_deleted(task, user) }

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
        perform_enqueued_jobs { described_class.list_created(list, user) }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("list_created")
      expect(event.user).to eq(user)
      expect(event.list).to eq(list)
      expect(event.task).to be_nil
    end

    it "includes visibility in metadata" do
      perform_enqueued_jobs { described_class.list_created(list, user) }

      event = AnalyticsEvent.last
      expect(event.metadata).to include("visibility" => list.visibility)
    end
  end

  describe ".list_shared" do
    let(:shared_with_user) { create(:user) }

    it "creates an AnalyticsEvent with event_type list_shared" do
      expect {
        perform_enqueued_jobs { described_class.list_shared(list, user, shared_with: shared_with_user, role: "editor") }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("list_shared")
      expect(event.user).to eq(user)
      expect(event.list).to eq(list)
    end

    it "includes shared_with_user_id and role in metadata" do
      perform_enqueued_jobs { described_class.list_shared(list, user, shared_with: shared_with_user, role: "viewer") }

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
        perform_enqueued_jobs { described_class.app_opened(user, platform: "ios") }
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.event_type).to eq("app_opened")
      expect(event.user).to eq(user)
      expect(event.task).to be_nil
      expect(event.list).to be_nil
    end

    it "includes platform and version in metadata" do
      perform_enqueued_jobs { described_class.app_opened(user, platform: "ios", version: "2.1.0") }

      event = AnalyticsEvent.last
      expect(event.metadata).to include(
        "platform" => "ios",
        "version" => "2.1.0"
      )
    end

    it "includes day_of_week and hour in metadata" do
      freeze_time do
        perform_enqueued_jobs { described_class.app_opened(user, platform: "android") }

        event = AnalyticsEvent.last
        expect(event.metadata["day_of_week"]).to eq(Time.current.strftime("%A"))
        expect(event.metadata["hour"]).to eq(Time.current.hour)
      end
    end
  end

  describe "error handling" do
    it "does not raise when job enqueueing fails" do
      allow(AnalyticsEventJob).to receive(:perform_later).and_raise(StandardError.new("Queue unavailable"))

      expect {
        described_class.app_opened(user, platform: "ios")
      }.not_to raise_error
    end

    it "logs the error when enqueueing fails" do
      allow(AnalyticsEventJob).to receive(:perform_later).and_raise(StandardError.new("Queue unavailable"))

      expect(Rails.logger).to receive(:error).with(/AnalyticsTracker failed to enqueue: Queue unavailable/)

      described_class.task_created(task, user)
    end

    it "reports enqueue failures to Sentry with context" do
      allow(AnalyticsEventJob).to receive(:perform_later).and_raise(StandardError.new("Queue unavailable"))
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)

      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_exception)

      described_class.app_opened(user, platform: "ios")

      expect(Sentry).to have_received(:capture_exception).with(
        instance_of(StandardError),
        hash_including(extra: hash_including(user_id: user.id, event_type: "app_opened"))
      )
    end

    it "throttles repeated Sentry reports for the same enqueue error" do
      allow(AnalyticsEventJob).to receive(:perform_later).and_raise(StandardError.new("Queue unavailable"))
      allow(Rails.cache).to receive(:read).and_return(nil, true)
      allow(Rails.cache).to receive(:write)

      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_exception)

      2.times { described_class.app_opened(user, platform: "ios") }

      expect(Sentry).to have_received(:capture_exception).once
    end
  end
end
