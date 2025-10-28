# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardDataService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user:) }

  describe '#call' do
    context 'when user is a client' do
      before { allow(user).to receive(:client?).and_return(true) }

      it 'returns client dashboard data' do
        result = service.call

        expect(result).to include(
          :blocking_tasks_count,
          :overdue_tasks_count,
          :awaiting_explanation_count,
          :coaches_count,
          :completion_rate_this_week,
          :recent_activity,
          :upcoming_deadlines
        )
      end
    end

    context 'when user is a coach' do
      before { allow(user).to receive(:client?).and_return(false) }

      it 'returns coach dashboard data' do
        result = service.call

        expect(result).to include(
          :clients_count,
          :total_overdue_tasks,
          :pending_explanations,
          :active_relationships,
          :recent_client_activity
        )
      end
    end
  end

  describe '#stats' do
    context 'when user is a client' do
      before { allow(user).to receive(:client?).and_return(true) }

      it 'returns client stats' do
        result = service.stats

        expect(result).to include(
          :total_tasks,
          :completed_tasks,
          :overdue_tasks,
          :completion_rate,
          :average_completion_time,
          :tasks_by_priority
        )
      end
    end

    context 'when user is a coach' do
      before { allow(user).to receive(:client?).and_return(false) }

      it 'returns coach stats' do
        result = service.stats

        expect(result).to include(
          :total_clients,
          :active_clients,
          :total_tasks_across_clients,
          :completed_tasks_across_clients,
          :average_client_completion_rate,
          :client_performance_summary
        )
      end
    end
  end

  describe 'caching' do
    before { allow(user).to receive(:client?).and_return(true) }

    it 'uses cache for dashboard data' do
      expect(Rails.cache).to receive(:fetch).with(
        "client_dashboard_#{user.id}_#{user.updated_at.to_i}",
        expires_in: ConfigurationHelper.cache_expiry
      ).and_call_original

      service.call
    end

    it 'uses cache for coach dashboard data' do
      allow(user).to receive(:client?).and_return(false)
      expect(Rails.cache).to receive(:fetch).with(
        "coach_dashboard_#{user.id}_#{user.updated_at.to_i}",
        expires_in: ConfigurationHelper.cache_expiry
      ).and_call_original

      service.call
    end
  end

  describe 'data calculations' do
    before { allow(user).to receive(:client?).and_return(true) }

    it 'calculates completion rate correctly' do
      # Create some tasks for the user
      list = create(:list, user: user)
      create(:task, list:, status: :done, updated_at: 1.day.ago)
      create(:task, list:, status: :pending, updated_at: 1.day.ago)

      result = service.call

      expect(result[:completion_rate_this_week]).to be_a(Numeric)
    end

    it 'handles empty task lists gracefully' do
      result = service.call

      expect(result[:completion_rate_this_week]).to eq(0)
    end
  end
end
