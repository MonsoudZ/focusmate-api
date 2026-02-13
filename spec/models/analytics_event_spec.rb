# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsEvent do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe "validations" do
    it "requires event_type" do
      event = build(:analytics_event, user: user, event_type: nil)
      expect(event).not_to be_valid
    end

    it "requires occurred_at" do
      event = build(:analytics_event, user: user, occurred_at: nil)
      expect(event).not_to be_valid
    end

    it "rejects invalid event_type" do
      event = build(:analytics_event, user: user, event_type: "invalid_event")
      expect(event).not_to be_valid
    end

    it "accepts valid task events" do
      AnalyticsEvent::TASK_EVENTS.each do |type|
        event = build(:analytics_event, user: user, event_type: type)
        expect(event).to be_valid, "expected #{type} to be valid"
      end
    end

    it "accepts valid list events" do
      AnalyticsEvent::LIST_EVENTS.each do |type|
        event = build(:analytics_event, user: user, event_type: type)
        expect(event).to be_valid, "expected #{type} to be valid"
      end
    end

    it "accepts valid user events" do
      AnalyticsEvent::USER_EVENTS.each do |type|
        event = build(:analytics_event, user: user, event_type: type)
        expect(event).to be_valid, "expected #{type} to be valid"
      end
    end
  end

  describe "associations" do
    it "belongs to user" do
      event = create(:analytics_event, user: user)
      expect(event.user).to eq(user)
    end

    it "optionally belongs to task" do
      event = create(:analytics_event, user: user, task: task)
      expect(event.task).to eq(task)
    end

    it "optionally belongs to list" do
      event = create(:analytics_event, user: user, list: list)
      expect(event.list).to eq(list)
    end
  end

  describe "scopes" do
    let!(:event) { create(:analytics_event, user: user, event_type: "task_created", occurred_at: Time.current) }
    let!(:old_event) { create(:analytics_event, user: user, event_type: "app_opened", occurred_at: 2.months.ago) }

    it ".for_user returns events for a specific user" do
      other_user = create(:user)
      create(:analytics_event, user: other_user, event_type: "app_opened")

      expect(AnalyticsEvent.for_user(user)).to include(event)
      expect(AnalyticsEvent.for_user(user)).not_to include(AnalyticsEvent.for_user(other_user).first)
    end

    it ".of_type filters by event type" do
      expect(AnalyticsEvent.of_type("task_created")).to include(event)
      expect(AnalyticsEvent.of_type("task_created")).not_to include(old_event)
    end

    it ".between filters by date range" do
      results = AnalyticsEvent.between(1.hour.ago, 1.hour.from_now)
      expect(results).to include(event)
      expect(results).not_to include(old_event)
    end

    it ".today returns today's events" do
      expect(AnalyticsEvent.today).to include(event)
      expect(AnalyticsEvent.today).not_to include(old_event)
    end
  end
end
