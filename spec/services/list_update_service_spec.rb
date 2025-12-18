require 'rails_helper'

RSpec.describe ListUpdateService do
  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: owner, name: 'Original Name') }

  describe '#update!' do
    context 'when user is the list owner' do
      it 'updates the list successfully' do
        service = described_class.new(list: list, user: owner)
        result = service.update!(attributes: { name: 'Updated Name' })

        expect(result).to eq(list)
        expect(list.reload.name).to eq('Updated Name')
      end

      it 'updates multiple attributes' do
        service = described_class.new(list: list, user: owner)
        service.update!(attributes: {
          name: 'New Name',
          description: 'New Description',
          visibility: 'public'
        })

        list.reload
        expect(list.name).to eq('New Name')
        expect(list.description).to eq('New Description')
        expect(list.visibility).to eq('public')
      end

      it 'returns the list object' do
        service = described_class.new(list: list, user: owner)
        result = service.update!(attributes: { name: 'Test' })

        expect(result).to be_a(List)
        expect(result).to eq(list)
      end
    end

    context 'when user has edit permissions via share' do
      before do
        create(:list_share, list: list, user: editor, can_edit: true, status: :accepted)
      end

      it 'updates the list successfully' do
        service = described_class.new(list: list, user: editor)
        result = service.update!(attributes: { name: 'Editor Updated' })

        expect(result).to eq(list)
        expect(list.reload.name).to eq('Editor Updated')
      end

      it 'allows multiple attribute updates' do
        service = described_class.new(list: list, user: editor)
        service.update!(attributes: {
          name: 'Edited Name',
          description: 'Edited Description'
        })

        list.reload
        expect(list.name).to eq('Edited Name')
        expect(list.description).to eq('Edited Description')
      end
    end

    context 'when user does not have edit permissions' do
      before do
        create(:list_share, list: list, user: unauthorized_user, can_edit: false, status: :accepted)
      end

      it 'raises UnauthorizedError' do
        service = described_class.new(list: list, user: unauthorized_user)

        expect {
          service.update!(attributes: { name: 'Unauthorized Update' })
        }.to raise_error(ListUpdateService::UnauthorizedError, "You do not have permission to edit this list")
      end

      it 'does not update the list' do
        service = described_class.new(list: list, user: unauthorized_user)

        expect {
          service.update!(attributes: { name: 'Unauthorized Update' })
        }.to raise_error(ListUpdateService::UnauthorizedError)

        expect(list.reload.name).to eq('Original Name')
      end
    end

    context 'when user is not the owner and has no share' do
      it 'raises UnauthorizedError' do
        service = described_class.new(list: list, user: unauthorized_user)

        expect {
          service.update!(attributes: { name: 'Unauthorized Update' })
        }.to raise_error(ListUpdateService::UnauthorizedError)
      end
    end

    context 'when validation fails' do
      it 'raises ValidationError with details' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.update!(attributes: { name: '' })
        }.to raise_error(ListUpdateService::ValidationError) do |error|
          expect(error.message).to eq('Validation failed')
          expect(error.details).to be_a(Hash)
          expect(error.details).to have_key(:name)
        end
      end

      it 'does not update the list on validation failure' do
        service = described_class.new(list: list, user: owner)

        expect {
          service.update!(attributes: { name: '' })
        }.to raise_error(ListUpdateService::ValidationError)

        expect(list.reload.name).to eq('Original Name')
      end
    end

    context 'when updating visibility' do
      it 'updates visibility successfully' do
        service = described_class.new(list: list, user: owner)

        service.update!(attributes: { visibility: 'public' })

        expect(list.reload.visibility).to eq('public')
      end
    end
  end

  describe 'UnauthorizedError' do
    it 'is a StandardError' do
      expect(ListUpdateService::UnauthorizedError.new).to be_a(StandardError)
    end
  end

  describe 'ValidationError' do
    it 'stores message and details' do
      error = ListUpdateService::ValidationError.new('Test error', { field: [ 'error' ] })

      expect(error.message).to eq('Test error')
      expect(error.details).to eq({ field: [ 'error' ] })
    end

    it 'handles empty details' do
      error = ListUpdateService::ValidationError.new('Test error')

      expect(error.message).to eq('Test error')
      expect(error.details).to eq({})
    end
  end
end
