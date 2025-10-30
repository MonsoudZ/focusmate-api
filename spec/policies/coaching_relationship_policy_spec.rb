# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoachingRelationshipPolicy, type: :policy do
  let(:coach) { create(:user) }
  let(:client) { create(:user) }
  let(:other_user) { create(:user) }
  let(:pending_relationship) { create(:coaching_relationship, coach: coach, client: client, status: :pending) }
  let(:active_relationship) { create(:coaching_relationship, coach: coach, client: client, status: :active) }

  describe '#request?' do
    it 'allows the client to request a relationship' do
      policy = described_class.new(client, pending_relationship)
      expect(policy.request?).to be true
    end

    it 'denies the coach from requesting a relationship' do
      policy = described_class.new(coach, pending_relationship)
      expect(policy.request?).to be false
    end

    it 'denies other users from requesting a relationship' do
      policy = described_class.new(other_user, pending_relationship)
      expect(policy.request?).to be false
    end
  end

  describe '#accept?' do
    it 'allows the coach to accept a pending relationship' do
      policy = described_class.new(coach, pending_relationship)
      expect(policy.accept?).to be true
    end

    it 'denies the client from accepting the relationship' do
      policy = described_class.new(client, pending_relationship)
      expect(policy.accept?).to be false
    end

    it 'denies accepting an active relationship' do
      policy = described_class.new(coach, active_relationship)
      expect(policy.accept?).to be false
    end

    it 'denies other users from accepting' do
      policy = described_class.new(other_user, pending_relationship)
      expect(policy.accept?).to be false
    end
  end

  describe '#decline?' do
    it 'allows the coach to decline a pending relationship' do
      policy = described_class.new(coach, pending_relationship)
      expect(policy.decline?).to be true
    end

    it 'denies the client from declining the relationship' do
      policy = described_class.new(client, pending_relationship)
      expect(policy.decline?).to be false
    end

    it 'denies declining an active relationship' do
      policy = described_class.new(coach, active_relationship)
      expect(policy.decline?).to be false
    end
  end

  describe '#cancel?' do
    it 'allows the client to cancel a pending relationship' do
      policy = described_class.new(client, pending_relationship)
      expect(policy.cancel?).to be true
    end

    it 'denies the coach from canceling the relationship' do
      policy = described_class.new(coach, pending_relationship)
      expect(policy.cancel?).to be false
    end

    it 'denies canceling an active relationship' do
      policy = described_class.new(client, active_relationship)
      expect(policy.cancel?).to be false
    end

    it 'denies other users from canceling' do
      policy = described_class.new(other_user, pending_relationship)
      expect(policy.cancel?).to be false
    end
  end

  describe '#terminate?' do
    it 'allows the coach to terminate an active relationship' do
      policy = described_class.new(coach, active_relationship)
      expect(policy.terminate?).to be true
    end

    it 'allows the client to terminate an active relationship' do
      policy = described_class.new(client, active_relationship)
      expect(policy.terminate?).to be true
    end

    it 'denies terminating a pending relationship' do
      policy = described_class.new(coach, pending_relationship)
      expect(policy.terminate?).to be false
    end

    it 'denies other users from terminating' do
      policy = described_class.new(other_user, active_relationship)
      expect(policy.terminate?).to be false
    end
  end
end
