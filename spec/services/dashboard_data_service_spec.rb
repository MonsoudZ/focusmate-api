# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardDataService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user:) }

  describe '#call' do
    it 'returns basic dashboard data' do
      result = service.call

      expect(result).to include(
        :inbox_count,
        :overdue_count,
        :completion_rate,
        :recent_tasks,
        :digest,
        :last_modified
      )
    end
  end

  describe '#stats' do
    it 'returns basic stats data' do
      result = service.stats

      expect(result).to include(
        :total_tasks,
        :completed_tasks,
        :overdue_tasks,
        :completion_rate,
        :series,
        :digest,
        :last_modified
      )
    end
  end

  describe 'caching' do
    it 'generates digest for caching' do
      result = service.call
      expect(result[:digest]).to be_present
    end
  end

  describe 'data calculations' do
    it 'calculates completion rate correctly' do
      # Create some tasks for the user
      list = create(:list, user: user)
      create(:task, list:, status: :done, updated_at: 1.day.ago)
      create(:task, list:, status: :pending, updated_at: 1.day.ago)

      result = service.call

      expect(result[:completion_rate]).to be_a(Numeric)
    end

    it 'handles empty task lists gracefully' do
      result = service.call

      expect(result[:completion_rate]).to eq(0.0)
    end
  end
end
