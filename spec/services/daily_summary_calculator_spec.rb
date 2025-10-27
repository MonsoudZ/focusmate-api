# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailySummaryCalculator do
  let(:user) { create(:user) }
  let(:date) { Date.current }
  let(:calculator) { described_class.new(user:, date:) }

  describe '#call' do
    it 'aggregates counts and sums' do
      # Create tasks for the user
      create_list(:task, 2, creator: user, status: :done, updated_at: Time.current)
      create(:task, creator: user, status: :pending, due_at: Time.current)
      create(:task, creator: user, status: :pending, due_at: 1.day.ago)

      result = calculator.call

      expect(result[:tasks_completed]).to eq(2)
      expect(result[:tasks_missed]).to eq(1)
      expect(result[:tasks_overdue]).to eq(1)
      expect(result[:total_tasks]).to eq(3)
      expect(result[:completion_rate]).to eq(66.67)
      expect(result[:positive]).to be true
      expect(result[:negative]).to be false
      expect(result[:has_overdue_tasks]).to be true
      expect(result[:priority]).to eq('high')
    end

    it 'handles zero tasks' do
      result = calculator.call

      expect(result[:tasks_completed]).to eq(0)
      expect(result[:tasks_missed]).to eq(0)
      expect(result[:tasks_overdue]).to eq(0)
      expect(result[:total_tasks]).to eq(0)
      expect(result[:completion_rate]).to eq(0.0)
      expect(result[:positive]).to be false
      expect(result[:negative]).to be false
      expect(result[:has_overdue_tasks]).to be false
      expect(result[:priority]).to eq('low')
    end

    it 'calculates medium priority for moderate completion rate' do
      create(:task, creator: user, status: :done, updated_at: Time.current)
      create(:task, creator: user, status: :done, updated_at: Time.current)
      create(:task, creator: user, status: :pending, due_at: Time.current)

      result = calculator.call

      expect(result[:completion_rate]).to eq(66.67)
      expect(result[:priority]).to eq('medium')
    end

    it 'generates correct title and description' do
      create(:task, creator: user, status: :done, updated_at: Time.current)
      create(:task, creator: user, status: :pending, due_at: Time.current)
      create(:task, creator: user, status: :pending, due_at: Time.current)

      result = calculator.call

      expect(result[:title]).to eq("Daily Summary - #{date.strftime('%B %d, %Y')}")
      expect(result[:description]).to eq("1 completed, 2 missed, 0 overdue (33.33%)")
    end

    it 'handles different dates' do
      yesterday = 1.day.ago.to_date
      calculator = described_class.new(user:, date: yesterday)

      create(:task, creator: user, status: :done, updated_at: yesterday.beginning_of_day)
      create(:task, creator: user, status: :pending, due_at: yesterday.end_of_day)

      result = calculator.call

      expect(result[:date]).to eq(yesterday)
      expect(result[:tasks_completed]).to eq(1)
      expect(result[:tasks_missed]).to eq(1)
    end
  end
end
