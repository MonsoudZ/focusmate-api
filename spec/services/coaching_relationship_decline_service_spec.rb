require 'rails_helper'

RSpec.describe CoachingRelationshipDeclineService do
  let(:coach) { create(:user, email: 'coach@example.com') }
  let(:client) { create(:user, email: 'client@example.com') }

  describe '#decline!' do
    context 'when coach invited client' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'pending')
      end

      it 'allows client to decline the invitation' do
        service = described_class.new(relationship: relationship, current_user: client)

        result = service.decline!

        expect(result).to be true
        relationship.reload
        expect(relationship.status).to eq('declined')
      end

      it 'queues a declined notification job' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.decline!
        }.to have_enqueued_job(NotificationJob).with('coaching_invitation_declined', relationship.id)
      end

      it 'raises UnauthorizedError when coach tries to decline' do
        service = described_class.new(relationship: relationship, current_user: coach)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end

      it 'raises UnauthorizedError when third party tries to decline' do
        other_user = create(:user)
        service = described_class.new(relationship: relationship, current_user: other_user)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end
    end

    context 'when client invited coach' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'client',
               status: 'pending')
      end

      it 'allows coach to decline the invitation' do
        service = described_class.new(relationship: relationship, current_user: coach)

        result = service.decline!

        expect(result).to be true
        relationship.reload
        expect(relationship.status).to eq('declined')
      end

      it 'queues a declined notification job' do
        service = described_class.new(relationship: relationship, current_user: coach)

        expect {
          service.decline!
        }.to have_enqueued_job(NotificationJob).with('coaching_invitation_declined', relationship.id)
      end

      it 'raises UnauthorizedError when client tries to decline' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end

      it 'raises UnauthorizedError when third party tries to decline' do
        other_user = create(:user)
        service = described_class.new(relationship: relationship, current_user: other_user)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end
    end

    context 'when relationship is already active' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'active',
               accepted_at: 1.day.ago)
      end

      it 'raises UnauthorizedError when client tries to decline active relationship' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end
    end

    context 'when relationship is already declined' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'declined')
      end

      it 'raises UnauthorizedError when trying to decline again' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.decline!
        }.to raise_error(CoachingRelationshipDeclineService::UnauthorizedError, 'You cannot decline this invitation')
      end
    end

    context 'notification handling' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'pending')
      end

      it 'handles notification job errors gracefully' do
        service = described_class.new(relationship: relationship, current_user: client)

        allow(NotificationJob).to receive(:perform_later).and_raise(StandardError.new('Job error'))
        allow(Rails.logger).to receive(:error)

        expect {
          result = service.decline!
          expect(result).to be true
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error queueing notification/)
      end
    end

    context 'persistence' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'pending')
      end

      it 'persists status change to database' do
        service = described_class.new(relationship: relationship, current_user: client)

        service.decline!

        relationship.reload
        expect(relationship.status).to eq('declined')
      end
    end
  end

  describe 'UnauthorizedError' do
    it 'is a StandardError' do
      error = CoachingRelationshipDeclineService::UnauthorizedError.new('Unauthorized')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Unauthorized')
    end
  end
end
