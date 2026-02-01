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

    it "is enqueued to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
