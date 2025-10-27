# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoachingRelationshipManager do
  let(:coach) { create(:user) }
  let(:client) { create(:user) }
  let(:relationship) { create(:coaching_relationship, coach:, client:, status: :pending) }

  describe '#accept!' do
    it 'accepts by coach' do
      described_class.new(relationship, coach).accept!
      expect(relationship.reload).to be_active
    end

    it 'prevents client from accepting' do
      expect { described_class.new(relationship, client).accept! }
        .to raise_error(Pundit::NotAuthorizedError)
    end

    it 'prevents accepting non-pending relationships' do
      relationship.update!(status: :active)
      expect { described_class.new(relationship, coach).accept! }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe '#decline!' do
    it 'declines by coach' do
      described_class.new(relationship, coach).decline!
      expect(relationship.reload).to be_declined
    end

    it 'prevents client from declining' do
      expect { described_class.new(relationship, client).decline! }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe '#cancel!' do
    it 'cancels by client' do
      described_class.new(relationship, client).cancel!
      expect(relationship.reload).to be_inactive
    end

    it 'prevents coach from cancelling' do
      expect { described_class.new(relationship, coach).cancel! }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe '#terminate!' do
    let(:active_relationship) { create(:coaching_relationship, coach:, client:, status: :active) }

    it 'terminates by coach' do
      described_class.new(active_relationship, coach).terminate!
      expect(active_relationship.reload).to be_inactive
    end

    it 'terminates by client' do
      described_class.new(active_relationship, client).terminate!
      expect(active_relationship.reload).to be_inactive
    end

    it 'prevents terminating non-active relationships' do
      expect { described_class.new(relationship, coach).terminate! }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe '#request!' do
    let(:new_relationship) { build(:coaching_relationship, coach:, client:, status: :pending) }

    it 'requests by client' do
      new_relationship.save!
      described_class.new(new_relationship, client).request!
      expect(new_relationship.reload).to be_pending
    end

    it 'prevents coach from requesting' do
      new_relationship.save!
      expect { described_class.new(new_relationship, coach).request! }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
