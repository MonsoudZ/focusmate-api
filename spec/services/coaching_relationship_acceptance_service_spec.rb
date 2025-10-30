require 'rails_helper'

RSpec.describe CoachingRelationshipAcceptanceService do
  let(:coach) { create(:user, email: 'coach@example.com') }
  let(:client) { create(:user, email: 'client@example.com') }

  describe '#accept!' do
    context 'when coach invited client' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'pending')
      end

      it 'allows client to accept the invitation' do
        service = described_class.new(relationship: relationship, current_user: client)

        result = service.accept!

        expect(result.status).to eq('active')
        expect(result.accepted_at).to be_present
        expect(result.accepted_at).to be_within(1.second).of(Time.current)
      end

      it 'includes coach and client associations in result' do
        service = described_class.new(relationship: relationship, current_user: client)

        result = service.accept!

        expect(result.association(:coach).loaded?).to be true
        expect(result.association(:client).loaded?).to be true
      end

      it 'queues an acceptance notification job' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.accept!
        }.to have_enqueued_job(NotificationJob).with('coaching_invitation_accepted', relationship.id)
      end

      it 'raises UnauthorizedError when coach tries to accept' do
        service = described_class.new(relationship: relationship, current_user: coach)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
      end

      it 'raises UnauthorizedError when third party tries to accept' do
        other_user = create(:user)
        service = described_class.new(relationship: relationship, current_user: other_user)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
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

      it 'allows coach to accept the invitation' do
        service = described_class.new(relationship: relationship, current_user: coach)

        result = service.accept!

        expect(result.status).to eq('active')
        expect(result.accepted_at).to be_present
        expect(result.accepted_at).to be_within(1.second).of(Time.current)
      end

      it 'queues an acceptance notification job' do
        service = described_class.new(relationship: relationship, current_user: coach)

        expect {
          service.accept!
        }.to have_enqueued_job(NotificationJob).with('coaching_invitation_accepted', relationship.id)
      end

      it 'raises UnauthorizedError when client tries to accept' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
      end

      it 'raises UnauthorizedError when third party tries to accept' do
        other_user = create(:user)
        service = described_class.new(relationship: relationship, current_user: other_user)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
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

      it 'raises UnauthorizedError when client tries to accept again' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
      end
    end

    context 'when relationship is declined' do
      let(:relationship) do
        create(:coaching_relationship,
               coach: coach,
               client: client,
               invited_by: 'coach',
               status: 'declined')
      end

      it 'raises UnauthorizedError when trying to accept declined relationship' do
        service = described_class.new(relationship: relationship, current_user: client)

        expect {
          service.accept!
        }.to raise_error(CoachingRelationshipAcceptanceService::UnauthorizedError, 'You cannot accept this invitation')
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
          result = service.accept!
          expect(result.status).to eq('active')
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

        service.accept!

        relationship.reload
        expect(relationship.status).to eq('active')
      end

      it 'persists accepted_at timestamp to database' do
        service = described_class.new(relationship: relationship, current_user: client)

        service.accept!

        relationship.reload
        expect(relationship.accepted_at).to be_present
      end
    end
  end

  describe 'UnauthorizedError' do
    it 'is a StandardError' do
      error = CoachingRelationshipAcceptanceService::UnauthorizedError.new('Unauthorized')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Unauthorized')
    end
  end
end
