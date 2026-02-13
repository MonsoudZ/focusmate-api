# frozen_string_literal: true

require "rails_helper"

RSpec.describe TodayTasksQuery do
  let(:user) { create(:user, timezone: "UTC") }
  let(:list) { create(:list, user: user) }

  # Use travel_to to freeze time for consistent testing
  around do |example|
    travel_to Time.zone.local(2024, 1, 15, 12, 0, 0) do
      example.run
    end
  end

  describe "#overdue" do
    let!(:overdue_task) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: :pending, skip_due_at_validation: true) }
    let!(:today_task) { create(:task, list: list, creator: user, due_at: Time.current, status: :pending) }
    let!(:completed_overdue) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: :done, skip_due_at_validation: true) }

    it "includes tasks past due" do
      query = described_class.new(user)
      expect(query.overdue).to include(overdue_task)
    end

    it "excludes tasks due today" do
      query = described_class.new(user)
      expect(query.overdue).not_to include(today_task)
    end

    it "excludes completed tasks" do
      query = described_class.new(user)
      expect(query.overdue).not_to include(completed_overdue)
    end
  end

  describe "#due_today" do
    let!(:today_morning) { create(:task, list: list, creator: user, due_at: Time.current.beginning_of_day + 1.hour, status: :pending) }
    let!(:today_evening) { create(:task, list: list, creator: user, due_at: Time.current.end_of_day - 1.hour, status: :pending) }
    let!(:yesterday) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: :pending, skip_due_at_validation: true) }
    let!(:tomorrow) { create(:task, list: list, creator: user, due_at: 1.day.from_now, status: :pending) }
    let!(:completed_today) { create(:task, list: list, creator: user, due_at: Time.current, status: :done) }

    it "includes tasks due today" do
      query = described_class.new(user)
      result = query.due_today
      expect(result).to include(today_morning, today_evening)
    end

    it "excludes tasks from other days" do
      query = described_class.new(user)
      result = query.due_today
      expect(result).not_to include(yesterday, tomorrow)
    end

    it "excludes completed tasks" do
      query = described_class.new(user)
      expect(query.due_today).not_to include(completed_today)
    end
  end

  describe "#completed_today" do
    let!(:completed_today) { create(:task, list: list, creator: user, status: :done, completed_at: Time.current) }
    let!(:completed_yesterday) { create(:task, list: list, creator: user, status: :done, completed_at: 1.day.ago) }
    let!(:pending_task) { create(:task, list: list, creator: user, status: :pending) }

    it "includes tasks completed today" do
      query = described_class.new(user)
      expect(query.completed_today).to include(completed_today)
    end

    it "excludes tasks completed on other days" do
      query = described_class.new(user)
      expect(query.completed_today).not_to include(completed_yesterday)
    end

    it "excludes pending tasks" do
      query = described_class.new(user)
      expect(query.completed_today).not_to include(pending_task)
    end

    it "respects limit" do
      15.times { create(:task, list: list, creator: user, status: :done, completed_at: Time.current) }
      query = described_class.new(user)
      expect(query.completed_today(limit: 5).count).to eq(5)
    end
  end

  describe "#upcoming" do
    let!(:tomorrow) { create(:task, list: list, creator: user, due_at: 1.day.from_now, status: :pending) }
    let!(:next_week) { create(:task, list: list, creator: user, due_at: 5.days.from_now, status: :pending) }
    let!(:today) { create(:task, list: list, creator: user, due_at: Time.current, status: :pending) }
    let!(:far_future) { create(:task, list: list, creator: user, due_at: 30.days.from_now, status: :pending) }

    it "includes tasks in the specified range" do
      query = described_class.new(user)
      result = query.upcoming(days: 7)
      expect(result).to include(tomorrow, next_week)
    end

    it "excludes tasks due today" do
      query = described_class.new(user)
      expect(query.upcoming(days: 7)).not_to include(today)
    end

    it "excludes tasks beyond the range" do
      query = described_class.new(user)
      expect(query.upcoming(days: 7)).not_to include(far_future)
    end
  end

  describe "#stats" do
    before do
      create(:task, list: list, creator: user, due_at: Time.current, status: :done, completed_at: Time.current)
      create(:task, list: list, creator: user, due_at: Time.current, status: :pending)
      create(:task, list: list, creator: user, due_at: 1.day.ago, status: :pending, skip_due_at_validation: true)
    end

    it "returns correct statistics" do
      query = described_class.new(user)
      stats = query.stats

      expect(stats[:total_due_today]).to eq(2)
      expect(stats[:completed_today]).to eq(1)
      expect(stats[:remaining_today]).to eq(1)
      expect(stats[:overdue_count]).to eq(1)
      expect(stats[:completion_percentage]).to eq(50)
    end
  end

  describe "#all_for_today" do
    it "returns hash with all sections" do
      query = described_class.new(user)
      result = query.all_for_today

      expect(result).to have_key(:overdue)
      expect(result).to have_key(:due_today)
      expect(result).to have_key(:completed_today)
    end
  end

  describe "filtering" do
    let(:other_user) { create(:user) }
    let(:other_list) { create(:list, user: other_user) }
    let!(:other_task) { create(:task, list: other_list, creator: other_user, due_at: Time.current) }

    it "excludes tasks from lists user has no access to" do
      query = described_class.new(user)
      expect(query.due_today).not_to include(other_task)
    end

    it "includes tasks from shared lists where user is a member" do
      shared_list = create(:list, user: other_user)
      create(:membership, list: shared_list, user: user, role: "editor")
      shared_task = create(:task, list: shared_list, creator: other_user, due_at: Time.current)

      query = described_class.new(user)
      expect(query.due_today).to include(shared_task)
    end

    it "excludes subtasks" do
      parent = create(:task, list: list, creator: user, due_at: Time.current)
      subtask = create(:task, list: list, creator: user, due_at: Time.current, parent_task: parent)

      query = described_class.new(user)
      expect(query.due_today).to include(parent)
      expect(query.due_today).not_to include(subtask)
    end

    it "excludes templates" do
      template = create(:task, list: list, creator: user, due_at: Time.current, is_template: true)

      query = described_class.new(user)
      expect(query.due_today).not_to include(template)
    end

    it "excludes deleted tasks" do
      deleted_task = create(:task, list: list, creator: user, due_at: Time.current)
      deleted_task.soft_delete!

      query = described_class.new(user)
      expect(query.due_today).not_to include(deleted_task)
    end
  end

  describe "timezone boundaries" do
    # User in America/New_York (UTC-5). Outer around freezes to
    # 2024-01-15 12:00 UTC = 2024-01-15 07:00 EST.
    # NY day boundaries: 05:00 UTC (midnight EST) .. 04:59:59 UTC+1day (23:59:59 EST)
    let(:ny_user) { create(:user, timezone: "America/New_York") }
    let(:ny_list) { create(:list, user: ny_user) }

    it "excludes tomorrow 12:01am local from due_today" do
      # 00:01 EST Jan 16 = 05:01 UTC Jan 16
      task = create(:task, list: ny_list, creator: ny_user,
                    due_at: Time.utc(2024, 1, 16, 5, 1, 0), status: :pending)

      query = described_class.new(ny_user)
      expect(query.due_today).not_to include(task)
    end

    it "includes tomorrow 12:01am local in upcoming" do
      # 00:01 EST Jan 16 = 05:01 UTC Jan 16
      task = create(:task, list: ny_list, creator: ny_user,
                    due_at: Time.utc(2024, 1, 16, 5, 1, 0), status: :pending)

      query = described_class.new(ny_user)
      expect(query.upcoming(days: 7)).to include(task)
    end

    it "includes today 11:59pm local in due_today" do
      # 23:59 EST Jan 15 = 04:59 UTC Jan 16
      task = create(:task, list: ny_list, creator: ny_user,
                    due_at: Time.utc(2024, 1, 16, 4, 59, 0), status: :pending)

      query = described_class.new(ny_user)
      expect(query.due_today).to include(task)
    end

    it "includes today 12:00am local (start of day) in due_today" do
      # 00:00 EST Jan 15 = 05:00 UTC Jan 15
      task = create(:task, list: ny_list, creator: ny_user,
                    due_at: Time.utc(2024, 1, 15, 5, 0, 0), status: :pending)

      query = described_class.new(ny_user)
      expect(query.due_today).to include(task)
    end

    it "puts yesterday 11:59pm local in overdue, not due_today" do
      # 23:59 EST Jan 14 = 04:59 UTC Jan 15
      task = create(:task, list: ny_list, creator: ny_user,
                    due_at: Time.utc(2024, 1, 15, 4, 59, 0), status: :pending,
                    skip_due_at_validation: true)

      query = described_class.new(ny_user)
      expect(query.overdue).to include(task)
      expect(query.due_today).not_to include(task)
    end
  end

  describe "timezone safety" do
    it "falls back to UTC when user timezone is invalid" do
      user.update_column(:timezone, "Invalid/Zone")
      task = create(:task, list: list, creator: user, due_at: Time.current, status: :pending)

      query = described_class.new(user)

      expect { query.due_today.to_a }.not_to raise_error
      expect(query.due_today).to include(task)
    end
  end
end
