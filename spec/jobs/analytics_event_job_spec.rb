# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsEventJob, type: :job do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe "#perform" do
    it "creates an AnalyticsEvent" do
      expect {
        described_class.new.perform(
          user_id: user.id,
          event_type: "task_created",
          metadata: { priority: "high" },
          task_id: task.id,
          list_id: list.id
        )
      }.to change(AnalyticsEvent, :count).by(1)
    end

    it "sets all attributes correctly" do
      described_class.new.perform(
        user_id: user.id,
        event_type: "list_created",
        metadata: { visibility: "private" },
        list_id: list.id,
        occurred_at: "2026-01-31T12:00:00Z"
      )

      event = AnalyticsEvent.last
      expect(event.user_id).to eq(user.id)
      expect(event.list_id).to eq(list.id)
      expect(event.event_type).to eq("list_created")
      expect(event.metadata).to eq({ "visibility" => "private" })
      expect(event.occurred_at).to eq(Time.parse("2026-01-31T12:00:00Z"))
    end

    it "handles nil task_id and list_id" do
      expect {
        described_class.new.perform(
          user_id: user.id,
          event_type: "app_opened",
          metadata: { platform: "ios" }
        )
      }.to change(AnalyticsEvent, :count).by(1)

      event = AnalyticsEvent.last
      expect(event.task_id).to be_nil
      expect(event.list_id).to be_nil
    end

    it "does not raise on database errors" do
      allow(AnalyticsEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)

      expect {
        described_class.new.perform(
          user_id: user.id,
          event_type: "task_created",
          metadata: {}
        )
      }.not_to raise_error
    end

    it "reports failures to Sentry with context" do
      allow(AnalyticsEvent).to receive(:create!).and_raise(StandardError.new("db down"))
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)

      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_exception)

      described_class.new.perform(
        user_id: user.id,
        event_type: "task_created",
        task_id: task.id,
        list_id: list.id,
        metadata: {}
      )

      expect(Sentry).to have_received(:capture_exception).with(
        instance_of(StandardError),
        hash_including(extra: hash_including(user_id: user.id, event_type: "task_created"))
      )
    end

    it "throttles repeated Sentry reports for the same error" do
      allow(AnalyticsEvent).to receive(:create!).and_raise(StandardError.new("db down"))
      allow(Rails.cache).to receive(:read).and_return(nil, true)
      allow(Rails.cache).to receive(:write)

      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_exception)

      2.times do
        described_class.new.perform(
          user_id: user.id,
          event_type: "task_created",
          metadata: {}
        )
      end

      expect(Sentry).to have_received(:capture_exception).once
    end

    it "is enqueued to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
