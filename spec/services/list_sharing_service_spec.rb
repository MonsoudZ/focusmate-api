require 'rails_helper'

RSpec.describe ListSharingService do
  let(:owner) { create(:user) }
  let(:target_user) { create(:user, email: 'target@example.com') }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: owner) }

  describe '#share!' do
    context 'when user is the list owner' do
      context 'with user_id' do
        it 'creates a new share successfully' do
          service = described_class.new(list: list, user: owner)

          share = service.share!(
            user_id: target_user.id,
            permissions: { can_edit: true, can_view: true }
          )

          expect(share).to be_persisted
          expect(share.user_id).to eq(target_user.id)
          expect(share.can_edit).to be true
          expect(share.can_view).to be true
          expect(share.status).to eq('accepted')
        end

        it 'sets all permissions correctly' do
          service = described_class.new(list: list, user: owner)

          share = service.share!(
            user_id: target_user.id,
            permissions: {
              can_view: true,
              can_edit: true,
              can_add_items: true,
              can_delete_items: false
            }
          )

          expect(share.can_view).to be true
          expect(share.can_edit).to be true
          expect(share.can_add_items).to be true
          expect(share.can_delete_items).to be false
        end
      end

      context 'with email' do
        it 'creates a share for existing user by email' do
          service = described_class.new(list: list, user: owner)

          share = service.share!(
            email: target_user.email,
            permissions: { can_view: true }
          )

          expect(share).to be_persisted
          expect(share.user_id).to eq(target_user.id)
          expect(share.email).to eq(target_user.email)
        end

        it 'handles case-insensitive email lookup' do
          service = described_class.new(list: list, user: owner)

          share = service.share!(
            email: target_user.email.upcase,
            permissions: { can_view: true }
          )

          expect(share).to be_persisted
          expect(share.user_id).to eq(target_user.id)
        end
      end

      context 'with non-existent user' do
        it 'raises ValidationError when user not found by email' do
          service = described_class.new(list: list, user: owner)

          expect {
            service.share!(
              email: 'nonexistent@example.com',
              permissions: {}
            )
          }.to raise_error(ListSharingService::ValidationError) do |error|
            expect(error.message).to eq('Validation failed')
            expect(error.details[:email]).to include('User not found')
          end
        end

        it 'raises NotFoundError when user not found by id' do
          service = described_class.new(list: list, user: owner)

          expect {
            service.share!(
              user_id: 999999,
              permissions: {}
            )
          }.to raise_error(ListSharingService::NotFoundError, 'User not found')
        end
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(list: list, user: unauthorized_user)

        expect {
          service.share!(
            user_id: target_user.id,
            permissions: {}
          )
        }.to raise_error(ListSharingService::UnauthorizedError, 'Only list owner can manage sharing')
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError when both user_id and email are blank' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.share!(user_id: nil, email: nil, permissions: {})
        }.to raise_error(ListSharingService::ValidationError) do |error|
          expect(error.message).to eq('Validation failed')
          expect(error.details[:email]).to include('is required')
        end
      end

      it 'raises ValidationError when email is empty string' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.share!(email: '', permissions: {})
        }.to raise_error(ListSharingService::ValidationError)
      end
    end

    context 'when share already exists' do
      it 'updates the existing share' do
        # Create an existing share
        existing_share = create(:list_share, list: list, user: target_user, email: target_user.email, can_edit: false)

        service = described_class.new(list: list, user: owner)

        # Service uses find_or_initialize_by, so it updates existing shares
        share = service.share!(
          user_id: target_user.id,
          permissions: { can_edit: true }
        )

        expect(share.id).to eq(existing_share.id)
        expect(share.can_edit).to be true
      end
    end
  end

  describe '#unshare!' do
    let!(:share) { create(:list_share, list: list, user: target_user) }

    context 'when user is the list owner' do
      it 'removes the share successfully' do
        service = described_class.new(list: list, user: owner)

        result = service.unshare!(user_id: target_user.id)

        expect(result).to be true
        expect(ListShare.find_by(list_id: list.id, user_id: target_user.id)).to be_nil
      end

      it 'returns true when share does not exist' do
        service = described_class.new(list: list, user: owner)

        result = service.unshare!(user_id: 999999)

        expect(result).to be true
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(list: list, user: unauthorized_user)

        expect {
          service.unshare!(user_id: target_user.id)
        }.to raise_error(ListSharingService::UnauthorizedError)
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError when user_id is blank' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.unshare!(user_id: nil)
        }.to raise_error(ListSharingService::ValidationError) do |error|
          expect(error.details[:user_id]).to include('is required')
        end
      end

      it 'raises ValidationError when user_id is empty string' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.unshare!(user_id: '')
        }.to raise_error(ListSharingService::ValidationError)
      end
    end
  end

  describe 'error classes' do
    it 'UnauthorizedError is a StandardError' do
      expect(ListSharingService::UnauthorizedError.new).to be_a(StandardError)
    end

    it 'ValidationError stores message and details' do
      error = ListSharingService::ValidationError.new('Test', { field: ['error'] })

      expect(error.message).to eq('Test')
      expect(error.details).to eq({ field: ['error'] })
    end

    it 'NotFoundError is a StandardError' do
      expect(ListSharingService::NotFoundError.new).to be_a(StandardError)
    end
  end
end
