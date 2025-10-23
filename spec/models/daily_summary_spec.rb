# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailySummary, type: :model do
  let(:coach) { create(:user, role: "coach") }
  let(:client) { create(:user, role: "client") }
  let(:coaching_relationship) { create(:coaching_relationship, coach: coach, client: client, invited_by: coach, status: :active) }
  let(:daily_summary) { build(:daily_summary, coaching_relationship: coaching_relationship, summary_date: Date.current, tasks_completed: 5, tasks_missed: 2, tasks_overdue: 1) }

  describe 'validations' do
    it 'belongs to coaching_relationship' do
      expect(daily_summary).to be_valid
      expect(daily_summary.coaching_relationship).to eq(coaching_relationship)
    end

    it 'requires summary_date' do
      daily_summary.summary_date = nil
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:summary_date]).to include("can't be blank")
    end

    it 'requires tasks_completed' do
      daily_summary.tasks_completed = nil
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_completed]).to include("can't be blank")
    end

    it 'validates tasks_completed is non-negative' do
      daily_summary.tasks_completed = -1
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_completed]).to include("must be greater than or equal to 0")
    end

    it 'requires tasks_missed' do
      daily_summary.tasks_missed = nil
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_missed]).to include("can't be blank")
    end

    it 'validates tasks_missed is non-negative' do
      daily_summary.tasks_missed = -1
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_missed]).to include("must be greater than or equal to 0")
    end

    it 'requires tasks_overdue' do
      daily_summary.tasks_overdue = nil
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_overdue]).to include("can't be blank")
    end

    it 'validates tasks_overdue is non-negative' do
      daily_summary.tasks_overdue = -1
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:tasks_overdue]).to include("must be greater than or equal to 0")
    end

    it 'validates unique summary_date per coaching_relationship' do
      daily_summary.save!
      
      duplicate_summary = build(:daily_summary, 
                                coaching_relationship: coaching_relationship, 
                                summary_date: daily_summary.summary_date)
      expect(duplicate_summary).not_to be_valid
      expect(duplicate_summary.errors[:summary_date]).to include("has already been taken")
    end

    it 'allows same summary_date for different coaching_relationships' do
      other_coach = create(:user, role: "coach")
      other_client = create(:user, role: "client")
      other_relationship = create(:coaching_relationship, coach: other_coach, client: other_client, invited_by: other_coach, status: :active)
      
      daily_summary.save!
      other_summary = build(:daily_summary, 
                           coaching_relationship: other_relationship, 
                           summary_date: daily_summary.summary_date)
      expect(other_summary).to be_valid
    end

    it 'validates summary_data is valid JSON' do
      daily_summary.summary_data = "invalid_json"
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:summary_data]).to include("is not a valid JSON")
    end

    it 'allows nil summary_data' do
      daily_summary.summary_data = nil
      expect(daily_summary).to be_valid
    end

    it 'allows valid JSON summary_data' do
      daily_summary.summary_data = { "key" => "value" }
      expect(daily_summary).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to coaching_relationship' do
      expect(daily_summary.coaching_relationship).to eq(coaching_relationship)
    end
  end

  describe 'scopes' do
    it 'has for_date scope' do
      summary1 = create(:daily_summary, coaching_relationship: coaching_relationship, summary_date: Date.current)
      summary2 = create(:daily_summary, coaching_relationship: coaching_relationship, summary_date: 1.day.ago)
      
      expect(DailySummary.for_date(Date.current)).to include(summary1)
      expect(DailySummary.for_date(Date.current)).not_to include(summary2)
    end

    it 'has for_coaching_relationship scope' do
      other_coach = create(:user, role: "coach")
      other_client = create(:user, role: "client")
      other_relationship = create(:coaching_relationship, coach: other_coach, client: other_client, invited_by: other_coach, status: :active)
      
      summary1 = create(:daily_summary, coaching_relationship: coaching_relationship)
      summary2 = create(:daily_summary, coaching_relationship: other_relationship)
      
      expect(DailySummary.for_coaching_relationship(coaching_relationship)).to include(summary1)
      expect(DailySummary.for_coaching_relationship(coaching_relationship)).not_to include(summary2)
    end

    it 'has recent scope' do
      recent_summary = create(:daily_summary, coaching_relationship: coaching_relationship, summary_date: Date.current)
      old_summary = create(:daily_summary, coaching_relationship: coaching_relationship, summary_date: 1.week.ago)
      
      expect(DailySummary.recent).to include(recent_summary)
      expect(DailySummary.recent).not_to include(old_summary)
    end

    it 'has with_tasks scope' do
      summary_with_tasks = create(:daily_summary, coaching_relationship: coaching_relationship, tasks_completed: 5, summary_date: Date.current)
      summary_without_tasks = create(:daily_summary, coaching_relationship: coaching_relationship, tasks_completed: 0, tasks_missed: 0, tasks_overdue: 0, summary_date: Date.current - 1.day)
      
      expect(DailySummary.with_tasks).to include(summary_with_tasks)
      expect(DailySummary.with_tasks).not_to include(summary_without_tasks)
    end
  end

  describe 'methods' do
    it 'calculates completion rate' do
      daily_summary.tasks_completed = 8
      daily_summary.tasks_missed = 2
      expect(daily_summary.completion_rate).to eq(80.0)
    end

    it 'handles zero total tasks' do
      daily_summary.tasks_completed = 0
      daily_summary.tasks_missed = 0
      expect(daily_summary.completion_rate).to eq(0.0)
    end

    it 'calculates total tasks' do
      daily_summary.tasks_completed = 5
      daily_summary.tasks_missed = 3
      expect(daily_summary.total_tasks).to eq(8)
    end

    it 'checks if summary is positive' do
      daily_summary.tasks_completed = 5
      daily_summary.tasks_missed = 2
      expect(daily_summary.positive?).to be true
      
      daily_summary.tasks_completed = 1
      daily_summary.tasks_missed = 5
      expect(daily_summary.positive?).to be false
    end

    it 'checks if summary is negative' do
      daily_summary.tasks_completed = 1
      daily_summary.tasks_missed = 5
      expect(daily_summary.negative?).to be true
      
      daily_summary.tasks_completed = 5
      daily_summary.tasks_missed = 2
      expect(daily_summary.negative?).to be false
    end

    it 'returns summary title' do
      daily_summary.summary_date = Date.new(2023, 12, 25)
      expect(daily_summary.title).to eq("Daily Summary - December 25, 2023")
    end

    it 'returns summary description' do
      daily_summary.tasks_completed = 5
      daily_summary.tasks_missed = 2
      daily_summary.tasks_overdue = 1
      
      description = daily_summary.description
      expect(description).to include("5 completed")
      expect(description).to include("2 missed")
      expect(description).to include("1 overdue")
    end

    it 'returns summary details' do
      daily_summary.summary_data = { "notes" => "Good progress", "mood" => "positive" }
      
      details = daily_summary.details
      expect(details).to include(:id, :summary_date, :tasks_completed, :tasks_missed, :tasks_overdue, :completion_rate, :summary_data)
    end

    it 'returns age in days' do
      daily_summary.summary_date = 3.days.ago.to_date
      expect(daily_summary.age_days).to eq(3)
    end

    it 'checks if summary is recent' do
      daily_summary.summary_date = Date.current
      expect(daily_summary.recent?).to be true
      
      daily_summary.summary_date = 1.week.ago.to_date
      expect(daily_summary.recent?).to be false
    end

    it 'returns priority level' do
      daily_summary.tasks_completed = 8
      daily_summary.tasks_missed = 1
      daily_summary.tasks_overdue = 1
      expect(daily_summary.priority).to eq("high")
      
      daily_summary.tasks_completed = 3
      daily_summary.tasks_missed = 3
      daily_summary.tasks_overdue = 0
      expect(daily_summary.priority).to eq("medium")
      
      daily_summary.tasks_completed = 1
      daily_summary.tasks_missed = 5
      daily_summary.tasks_overdue = 0
      expect(daily_summary.priority).to eq("low")
    end

    it 'generates summary report' do
      daily_summary.tasks_completed = 5
      daily_summary.tasks_missed = 2
      daily_summary.tasks_overdue = 1
      daily_summary.summary_data = { "notes" => "Good day" }
      
      report = daily_summary.generate_report
      expect(report).to include(:date, :completion_rate, :tasks_completed, :tasks_missed, :tasks_overdue, :notes)
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      daily_summary.tasks_completed = nil
      daily_summary.tasks_missed = nil
      daily_summary.tasks_overdue = nil
      daily_summary.valid?
      
      expect(daily_summary.tasks_completed).to eq(0)
      expect(daily_summary.tasks_missed).to eq(0)
      expect(daily_summary.tasks_overdue).to eq(0)
    end

    it 'does not override existing values' do
      daily_summary.tasks_completed = 5
      daily_summary.valid?
      expect(daily_summary.tasks_completed).to eq(5)
    end

    it 'validates JSON format of summary_data' do
      daily_summary.summary_data = { "key" => "value" }
      daily_summary.valid?
      expect(daily_summary.summary_data).to eq({ "key" => "value" })
    end
  end

  describe 'soft deletion' do
    it 'soft deletes daily summary' do
      daily_summary.save!
      daily_summary.soft_delete!
      expect(daily_summary.deleted?).to be true
      expect(daily_summary.deleted_at).not_to be_nil
    end

    it 'restores soft deleted daily summary' do
      daily_summary.save!
      daily_summary.soft_delete!
      daily_summary.restore!
      expect(daily_summary.deleted?).to be false
      expect(daily_summary.deleted_at).to be_nil
    end

    it 'excludes soft deleted summaries from default scope' do
      daily_summary.save!
      daily_summary.soft_delete!
      expect(DailySummary.all).not_to include(daily_summary)
      expect(DailySummary.with_deleted).to include(daily_summary)
    end
  end

  describe 'statistics' do
    it 'calculates coaching relationship statistics' do
      create(:daily_summary, coaching_relationship: coaching_relationship, tasks_completed: 5, tasks_missed: 2, summary_date: Date.current)
      create(:daily_summary, coaching_relationship: coaching_relationship, tasks_completed: 3, tasks_missed: 1, summary_date: Date.current - 1.day)
      
      stats = DailySummary.statistics_for_coaching_relationship(coaching_relationship)
      expect(stats[:total_summaries]).to eq(2)
      expect(stats[:total_tasks_completed]).to eq(8)
      expect(stats[:total_tasks_missed]).to eq(3)
      expect(stats[:average_completion_rate]).to eq(72.73)
    end

    it 'handles empty statistics' do
      stats = DailySummary.statistics_for_coaching_relationship(coaching_relationship)
      expect(stats[:total_summaries]).to eq(0)
      expect(stats[:total_tasks_completed]).to eq(0)
      expect(stats[:total_tasks_missed]).to eq(0)
      expect(stats[:average_completion_rate]).to eq(0.0)
    end
  end

  describe 'date handling' do
    it 'handles different date formats' do
      daily_summary.summary_date = "2023-12-25"
      expect(daily_summary).to be_valid
      expect(daily_summary.summary_date).to eq(Date.new(2023, 12, 25))
    end

    it 'validates summary_date is not in future' do
      daily_summary.summary_date = 1.day.from_now.to_date
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:summary_date]).to include("cannot be in the future")
    end

    it 'allows today as summary_date' do
      daily_summary.summary_date = Date.current
      expect(daily_summary).to be_valid
    end
  end

  describe 'coaching relationship integration' do
    it 'belongs to active coaching relationship' do
      expect(daily_summary.coaching_relationship.status).to eq("active")
    end

    it 'cannot be created for inactive coaching relationship' do
      coaching_relationship.update!(status: :inactive)
      daily_summary = build(:daily_summary, coaching_relationship: coaching_relationship)
      expect(daily_summary).not_to be_valid
      expect(daily_summary.errors[:coaching_relationship]).to include("must be active")
    end

    it 'can be created for active coaching relationship' do
      expect(daily_summary).to be_valid
    end
  end
end
