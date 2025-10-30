require 'rails_helper'

RSpec.describe CoachingRelationshipCreationService do
  let(:coach) { create(:user, email: 'coach@example.com') }
  let(:client) { create(:user, email: 'client@example.com') }

  describe '#create!' do
    context 'when coach invites client' do
      it 'creates a pending relationship with coach as current user' do
        params = { client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship).to be_persisted
        expect(relationship.coach_id).to eq(coach.id)
        expect(relationship.client_id).to eq(client.id)
        expect(relationship.invited_by).to eq('coach')
        expect(relationship.status).to eq('pending')
      end

      it 'normalizes client email with uppercase letters' do
        params = { client_email: client.email.upcase }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.client_id).to eq(client.id)
      end

      it 'normalizes client email with whitespace' do
        params = { client_email: "  #{client.email}  " }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.client_id).to eq(client.id)
      end

      it 'queues a notification job' do
        params = { client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to have_enqueued_job(NotificationJob).with('coaching_invitation_sent', anything)
      end

      it 'explicitly sets invited_by to coach when specified' do
        params = { client_email: client.email, invited_by: 'coach' }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.invited_by).to eq('coach')
      end

      it 'includes coach and client associations in result' do
        params = { client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.association(:coach).loaded?).to be true
        expect(relationship.association(:client).loaded?).to be true
      end
    end

    context 'when client invites coach' do
      it 'creates a pending relationship with client as current user' do
        params = { coach_email: coach.email }
        service = described_class.new(current_user: client, params: params)

        relationship = service.create!

        expect(relationship).to be_persisted
        expect(relationship.coach_id).to eq(coach.id)
        expect(relationship.client_id).to eq(client.id)
        expect(relationship.invited_by).to eq('client')
        expect(relationship.status).to eq('pending')
      end

      it 'normalizes coach email with uppercase letters' do
        params = { coach_email: coach.email.upcase }
        service = described_class.new(current_user: client, params: params)

        relationship = service.create!

        expect(relationship.coach_id).to eq(coach.id)
      end

      it 'explicitly sets invited_by to client when specified' do
        params = { coach_email: coach.email, invited_by: 'client' }
        service = described_class.new(current_user: client, params: params)

        relationship = service.create!

        expect(relationship.invited_by).to eq('client')
      end
    end

    context 'when both emails are provided' do
      it 'defaults to coach inviting client when invited_by is not specified' do
        params = { coach_email: coach.email, client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.coach_id).to eq(coach.id)
        expect(relationship.client_id).to eq(client.id)
        expect(relationship.invited_by).to eq('coach')
      end

      it 'respects invited_by parameter when set to coach' do
        params = { coach_email: coach.email, client_email: client.email, invited_by: 'coach' }
        service = described_class.new(current_user: coach, params: params)

        relationship = service.create!

        expect(relationship.invited_by).to eq('coach')
      end

      it 'respects invited_by parameter when set to client' do
        params = { coach_email: coach.email, client_email: client.email, invited_by: 'client' }
        service = described_class.new(current_user: client, params: params)

        relationship = service.create!

        expect(relationship.invited_by).to eq('client')
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError when both emails are missing' do
        params = {}
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'Must provide coach_email or client_email')
      end

      it 'raises ValidationError when both emails are blank' do
        params = { coach_email: '', client_email: '' }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'Must provide coach_email or client_email')
      end

      it 'raises ValidationError when both emails are whitespace' do
        params = { coach_email: '   ', client_email: '   ' }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'Must provide coach_email or client_email')
      end
    end

    context 'when user not found' do
      it 'raises NotFoundError when client email does not exist' do
        params = { client_email: 'nonexistent@example.com' }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::NotFoundError, 'Client not found with that email')
      end

      it 'raises NotFoundError when coach email does not exist' do
        params = { coach_email: 'nonexistent@example.com' }
        service = described_class.new(current_user: client, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::NotFoundError, 'Coach not found with that email')
      end
    end

    context 'when attempting self-invitation' do
      it 'raises ValidationError when inviting self as client' do
        params = { client_email: coach.email }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'You cannot invite yourself')
      end

      it 'raises ValidationError when inviting self as coach' do
        params = { coach_email: client.email }
        service = described_class.new(current_user: client, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'You cannot invite yourself')
      end

      it 'detects self-invitation with case-insensitive email' do
        params = { client_email: coach.email.upcase }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'You cannot invite yourself')
      end
    end

    context 'when relationship already exists' do
      before do
        create(:coaching_relationship, coach: coach, client: client)
      end

      it 'raises ValidationError when creating duplicate relationship' do
        params = { client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'Relationship already exists')
      end

      it 'raises ValidationError regardless of invitation direction' do
        params = { coach_email: coach.email }
        service = described_class.new(current_user: client, params: params)

        expect {
          service.create!
        }.to raise_error(CoachingRelationshipCreationService::ValidationError, 'Relationship already exists')
      end
    end

    context 'notification handling' do
      it 'handles notification job errors gracefully' do
        params = { client_email: client.email }
        service = described_class.new(current_user: coach, params: params)

        allow(NotificationJob).to receive(:perform_later).and_raise(StandardError.new('Job error'))
        allow(Rails.logger).to receive(:error)

        expect {
          relationship = service.create!
          expect(relationship).to be_persisted
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Error queueing notification/)
      end
    end
  end

  describe 'ValidationError' do
    it 'is a StandardError' do
      error = CoachingRelationshipCreationService::ValidationError.new('Test error')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Test error')
    end
  end

  describe 'NotFoundError' do
    it 'is a StandardError' do
      error = CoachingRelationshipCreationService::NotFoundError.new('Not found')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Not found')
    end
  end
end
