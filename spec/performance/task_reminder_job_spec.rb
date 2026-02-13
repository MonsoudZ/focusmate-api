# frozen_string_literal: true

require "rails_helper"
require "benchmark"

RSpec.describe "TaskReminderJob Performance", type: :performance do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  before do
    allow(PushNotifications::Sender).to receive(:send_task_reminder).and_return(true)
  end

  describe "query efficiency" do
    it "uses linear queries for updates but not N+1 for associations" do
      # Create varying numbers of tasks
      create_list(:task, 10, list: list, creator: user, due_at: 5.minutes.from_now)

      queries_10 = collect_queries { TaskReminderJob.new.perform }
      select_queries_10 = queries_10.count { |q| q.start_with?("SELECT") && q.include?("users") }

      # Reset reminder_sent_at for next test
      Task.update_all(reminder_sent_at: nil)

      create_list(:task, 40, list: list, creator: user, due_at: 5.minutes.from_now)

      queries_50 = collect_queries { TaskReminderJob.new.perform }
      select_queries_50 = queries_50.count { |q| q.start_with?("SELECT") && q.include?("users") }

      # User SELECT queries should be constant (eager loaded), not growing with task count
      # Allow small variance for different batch strategies
      expect(select_queries_50).to be <= (select_queries_10 + 2)
    end

    it "includes necessary associations to avoid N+1" do
      assignee = create(:user)
      create(:membership, list: list, user: assignee)
      create_list(:task, 5, list: list, creator: user, assigned_to: assignee, due_at: 5.minutes.from_now)

      queries = collect_queries { TaskReminderJob.new.perform }

      # Should not have repeated SELECT queries for individual users
      user_select_queries = queries.select { |q| q.start_with?("SELECT") && q.include?("FROM \"users\"") }
      expect(user_select_queries.count).to be <= 2  # One batch for creators, one for assignees
    end
  end

  describe "execution time" do
    before do
      # Create test data
      50.times do |i|
        create(:task,
          list: list,
          creator: user,
          due_at: (i % 10 + 1).minutes.from_now,
          notification_interval_minutes: 15
        )
      end
    end

    it "completes within acceptable time" do
      time = Benchmark.realtime { TaskReminderJob.new.perform }

      expect(time).to be < 5.0  # Should complete in under 5 seconds
    end

    it "handles batch processing efficiently" do
      # Create more tasks
      100.times do |i|
        create(:task,
          list: list,
          creator: user,
          due_at: (i % 10 + 1).minutes.from_now,
          notification_interval_minutes: 15
        )
      end

      time = Benchmark.realtime { TaskReminderJob.new.perform }

      # Even with 150 tasks, should still be fast
      expect(time).to be < 10.0
    end
  end

  describe "memory usage" do
    it "does not load all tasks into memory at once" do
      # Create many tasks
      100.times do |i|
        create(:task,
          list: list,
          creator: user,
          due_at: (i % 10 + 1).minutes.from_now,
          notification_interval_minutes: 15
        )
      end

      # Track retained objects after explicit GC to reduce suite-order noise.
      before_objects = retained_object_count

      TaskReminderJob.new.perform

      after_objects = retained_object_count
      new_objects = [ after_objects - before_objects, 0 ].max

      # Keep a conservative cap that catches real regressions without flaking on suite growth.
      expect(new_objects).to be < 12_000
    end
  end

  private

  def count_queries(&block)
    collect_queries(&block).count
  end

  def retained_object_count
    GC.start(full_mark: true, immediate_sweep: true)
    ObjectSpace.count_objects.fetch(:T_OBJECT, 0)
  end
end
