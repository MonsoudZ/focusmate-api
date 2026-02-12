# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringTaskGenerationJob, type: :job do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  def create_recurring(title: "Daily task", due_at: 1.day.ago, complete_instance: true, **recurrence_overrides)
    service = RecurringTaskService.new(user)
    recurrence_params = { pattern: "daily", interval: 1 }.merge(recurrence_overrides)
    recurring = service.create_recurring_task(
      list: list,
      params: { title: title, due_at: due_at },
      recurrence_params: recurrence_params
    )
    recurring[:instance].update!(status: "done", completed_at: Time.current) if complete_instance
    recurring
  end

  def stub_generation_failure
    allow_any_instance_of(RecurringTaskService).to receive(:generate_next_instance)
      .and_raise(StandardError.new("generation failed"))
  end

  def stub_sentry
    stub_const("Sentry", Class.new) unless defined?(Sentry)
    allow(Sentry).to receive(:capture_exception)
  end

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
      create_recurring

      result = described_class.new.perform

      expect(result[:generated]).to eq(1)
      expect(result[:errors]).to eq(0)
    end

    it "does not increment generated count when recurrence has ended" do
      create_recurring(title: "One-time recurring task", count: 1)

      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:errors]).to eq(0)
    end

    it "skips templates that already have a pending instance" do
      create_recurring(due_at: 1.day.from_now, complete_instance: false)

      result = described_class.new.perform

      expect(result[:generated]).to eq(0)
      expect(result[:skipped_pending_instance]).to eq(1)
    end

    it "skips templates whose list is deleted" do
      create_recurring
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
      create_recurring(title: "Failing task")
      stub_generation_failure
      allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

      result = described_class.new.perform

      expect(result[:errors]).to eq(1)
      expect(result[:generated]).to eq(0)
    end

    it "continues when Sentry reporting fails during error handling" do
      create_recurring(title: "Failing task")
      stub_generation_failure

      stub_const("Sentry", Class.new) unless defined?(Sentry)
      allow(Sentry).to receive(:capture_exception).and_raise(StandardError.new("sentry down"))

      expect { described_class.new.perform }.not_to raise_error
    end

    it "reports generation failures to Sentry with context" do
      recurring = create_recurring(title: "Failing task")
      stub_generation_failure
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)
      stub_sentry

      described_class.new.perform

      expect(Sentry).to have_received(:capture_exception).with(
        instance_of(StandardError),
        hash_including(extra: hash_including(template_id: recurring[:template].id))
      )
    end

    it "throttles repeated Sentry reports for the same generation error" do
      create_recurring(title: "Failing task one")
      create_recurring(title: "Failing task two")
      stub_generation_failure
      allow(Rails.cache).to receive(:read).and_return(nil, true)
      allow(Rails.cache).to receive(:write)
      stub_sentry

      described_class.new.perform

      expect(Sentry).to have_received(:capture_exception).once
    end

    it "keeps latest-instance lookup queries near-constant as template count grows" do
      create_templates_with_pending_instances(3)

      small_queries = collect_queries do
        described_class.new.perform
      end

      create_templates_with_pending_instances(17)

      large_queries = collect_queries do
        described_class.new.perform
      end

      small_instance_selects = latest_instance_select_count(small_queries)
      large_instance_selects = latest_instance_select_count(large_queries)

      expect(large_instance_selects).to be <= (small_instance_selects + 1)
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

    it "keeps a dedicated latest-instance index for scale" do
      index_names = ActiveRecord::Base.connection.indexes(:tasks).map(&:name)
      expect(index_names).to include("index_tasks_on_template_due_id_not_deleted")
    end
  end

  def create_templates_with_pending_instances(count)
    count.times do |i|
      template = create(
        :task,
        list: list,
        creator: user,
        title: "Recurring Template #{i}",
        is_template: true,
        template_type: "recurring",
        is_recurring: true,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        due_at: 1.day.ago
      )

      create(
        :task,
        list: list,
        creator: user,
        title: "Instance #{i}",
        template: template,
        due_at: 1.day.from_now,
        status: "pending"
      )
    end
  end

  def latest_instance_select_count(queries)
    queries.count do |sql|
      sql.start_with?("SELECT") &&
        sql.include?("FROM \"tasks\"") &&
        sql.include?("\"tasks\".\"template_id\"")
    end
  end
end
