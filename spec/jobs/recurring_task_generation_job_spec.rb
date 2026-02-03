# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringTaskGenerationJob, type: :job do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe "#perform" do
    it "returns generated and error counts" do
      result = described_class.new.perform

      expect(result).to eq({
        generated: 0,
        errors: 0,
        skipped_deleted_list: 0,
        skipped_pending_instance: 0,
        skipped_no_instances: 0
      })
    end

    it "generates next instance when no pending instance exists" do
      service = RecurringTaskService.new(user)
      recurring = service.create_recurring_task(
        list: list,
        params: { title: "Daily task", due_at: 1.day.ago },
        recurrence_params: { pattern: "daily", interval: 1 }
      )

      # Complete the first instance so there's no pending instance
      instance = recurring[:instance]
      instance.update!(status: "done", completed_at: Time.current)

      result = described_class.new.perform

      expect(result[:generated]).to eq(1)
      expect(result[:errors]).to eq(0)
    end

    it "does not increment generated count when recurrence has ended" do
      service = RecurringTaskService.new(user)
      recurring = service.create_recurring_task(
        list: list,
        params: { title: "One-time recurring task", due_at: 1.day.ago },
        recurrence_params: { pattern: "daily", interval: 1, count: 1 }
      )

      recurring[:instance].update!(status: "done", completed_at: Time.current)

      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:errors]).to eq(0)
    end

    it "skips templates that already have a pending instance" do
      service = RecurringTaskService.new(user)
      service.create_recurring_task(
        list: list,
        params: { title: "Daily task", due_at: 1.day.from_now },
        recurrence_params: { pattern: "daily", interval: 1 }
      )

      # Instance is pending, so no new one should be generated
      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:skipped_pending_instance]).to eq(1)
    end

    it "skips templates whose list is deleted" do
      service = RecurringTaskService.new(user)
      recurring = service.create_recurring_task(
        list: list,
        params: { title: "Daily task", due_at: 1.day.ago },
        recurrence_params: { pattern: "daily", interval: 1 }
      )

      recurring[:instance].update!(status: "done", completed_at: Time.current)
      list.update_column(:deleted_at, Time.current)

      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:skipped_deleted_list]).to eq(1)
    end

    it "skips templates with no completed instances" do
      # Create a template directly without an instance
      list.tasks.create!(
        creator: user,
        title: "Orphan template",
        is_template: true,
        template_type: "recurring",
        is_recurring: true,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        status: :pending,
        due_at: 1.day.ago
      )

      # Delete all instances (non-template tasks)
      Task.where(is_template: false).destroy_all

      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:skipped_no_instances]).to eq(1)
    end

    it "handles errors gracefully and continues processing" do
      service = RecurringTaskService.new(user)
      recurring = service.create_recurring_task(
        list: list,
        params: { title: "Failing task", due_at: 1.day.ago },
        recurrence_params: { pattern: "daily", interval: 1 }
      )
      recurring[:instance].update!(status: "done", completed_at: Time.current)

      allow_any_instance_of(RecurringTaskService).to receive(:generate_next_instance)
        .and_raise(StandardError.new("generation failed"))

      allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

      result = described_class.new.perform

      expect(result[:errors]).to eq(1)
      expect(result[:generated]).to eq(0)
    end

    it "continues when Sentry reporting fails during error handling" do
      service = RecurringTaskService.new(user)
      recurring = service.create_recurring_task(
        list: list,
        params: { title: "Failing task", due_at: 1.day.ago },
        recurrence_params: { pattern: "daily", interval: 1 }
      )
      recurring[:instance].update!(status: "done", completed_at: Time.current)

      allow_any_instance_of(RecurringTaskService).to receive(:generate_next_instance)
        .and_raise(StandardError.new("generation failed"))

      if defined?(Sentry)
        allow(Sentry).to receive(:capture_exception).and_raise(StandardError.new("sentry down"))
      else
        stub_const("Sentry", Class.new)
        allow(Sentry).to receive(:capture_exception).and_raise(StandardError.new("sentry down"))
      end

      expect { described_class.new.perform }.not_to raise_error
    end

    it "logs completion with counts" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "recurring_task_generation_completed"
      ))

      described_class.new.perform
    end

    it "is enqueued to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
