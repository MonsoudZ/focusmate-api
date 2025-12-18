require 'rails_helper'

RSpec.describe ListCreationService do
  let(:user) { create(:user) }

  describe '#create!' do
    context 'with valid params' do
      it 'creates a list successfully' do
        params = { name: 'My List', description: 'Test description' }
        service = described_class.new(user: user, params: params)

        list = service.create!

        expect(list).to be_persisted
        expect(list.name).to eq('My List')
        expect(list.description).to eq('Test description')
        expect(list.user_id).to eq(user.id)
      end

      it 'sets default visibility to private' do
        params = { name: 'My List' }
        service = described_class.new(user: user, params: params)

        list = service.create!

        expect(list.visibility).to eq('private')
      end

      it 'allows custom visibility' do
        params = { name: 'Public List', visibility: 'public' }
        service = described_class.new(user: user, params: params)

        list = service.create!

        expect(list.visibility).to eq('public')
      end

      it 'creates list with only name' do
        params = { name: 'Minimal List' }
        service = described_class.new(user: user, params: params)

        list = service.create!

        expect(list).to be_persisted
        expect(list.name).to eq('Minimal List')
        expect(list.description).to be_nil
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError when name is missing' do
        params = { description: 'No name' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError) do |error|
          expect(error.message).to eq('Validation failed')
          expect(error.details).to be_present
        end
      end

      it 'raises ValidationError when name is blank' do
        params = { name: '' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError)
      end

      it 'raises ValidationError when name is nil' do
        params = { name: nil }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError)
      end
    end

    context 'with empty params' do
      it 'raises ValidationError with empty hash' do
        params = {}
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError)
      end

      it 'raises ValidationError when params only contain controller/action keys' do
        params = { controller: 'lists', action: 'create' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError)
      end
    end

    context 'error handling' do
      it 'includes error details in ValidationError' do
        params = { name: '' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(ListCreationService::ValidationError) do |error|
          expect(error.details).to be_a(Hash)
          expect(error.details).to have_key(:name)
        end
      end

      it 'preserves model validation errors' do
        params = { name: 'a' * 300 } # Assuming name has a length limit
        service = described_class.new(user: user, params: params)

        begin
          service.create!
        rescue ListCreationService::ValidationError => e
          expect(e.details).to be_a(Hash)
        end
      end
    end
  end

  describe 'ValidationError' do
    it 'stores message and details' do
      error = ListCreationService::ValidationError.new('Test error', { field: [ 'error' ] })

      expect(error.message).to eq('Test error')
      expect(error.details).to eq({ field: [ 'error' ] })
    end

    it 'handles empty details' do
      error = ListCreationService::ValidationError.new('Test error')

      expect(error.message).to eq('Test error')
      expect(error.details).to eq({})
    end
  end
end
