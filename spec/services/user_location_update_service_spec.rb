require 'rails_helper'

RSpec.describe UserLocationUpdateService do
  let(:user) { create(:user) }

  describe '#update!' do
    context 'with valid coordinates' do
      it 'updates user latitude and longitude' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        result = service.update!

        expect(result.latitude).to eq(37.7749)
        expect(result.longitude).to eq(-122.4194)
      end

      it 'updates location_updated_at timestamp' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        result = service.update!

        expect(result.location_updated_at).to be_present
        expect(result.location_updated_at).to be_within(1.second).of(Time.current)
      end

      it 'creates a UserLocation history record' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        expect {
          service.update!
        }.to change { user.user_locations.count }.by(1)
      end

      it 'stores correct coordinates in history record' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        service.update!

        history = user.user_locations.last
        expect(history.latitude).to eq(37.7749)
        expect(history.longitude).to eq(-122.4194)
        expect(history.recorded_at).to be_within(1.second).of(Time.current)
      end

      it 'logs location update info' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        allow(Rails.logger).to receive(:info)

        service.update!

        expect(Rails.logger).to have_received(:info).with(/Updating location for user #{user.id}/)
        expect(Rails.logger).to have_received(:info).with(/Location updated successfully/)
      end

      it 'converts string coordinates to float' do
        service = described_class.new(user: user, latitude: '40.7128', longitude: '-74.0060')

        result = service.update!

        expect(result.latitude).to eq(40.7128)
        expect(result.longitude).to eq(-74.006)
      end

      it 'handles integer coordinates' do
        service = described_class.new(user: user, latitude: 40, longitude: -74)

        result = service.update!

        expect(result.latitude).to eq(40.0)
        expect(result.longitude).to eq(-74.0)
      end

      it 'handles negative coordinates' do
        service = described_class.new(user: user, latitude: -33.8688, longitude: 151.2093)

        result = service.update!

        expect(result.latitude).to eq(-33.8688)
        expect(result.longitude).to eq(151.2093)
      end

      it 'handles zero coordinates' do
        service = described_class.new(user: user, latitude: 0.0, longitude: 0.0)

        result = service.update!

        expect(result.latitude).to eq(0.0)
        expect(result.longitude).to eq(0.0)
      end

      it 'handles coordinates at extremes' do
        service = described_class.new(user: user, latitude: 90.0, longitude: 180.0)

        result = service.update!

        expect(result.latitude).to eq(90.0)
        expect(result.longitude).to eq(180.0)
      end

      it 'handles negative extremes' do
        service = described_class.new(user: user, latitude: -90.0, longitude: -180.0)

        result = service.update!

        expect(result.latitude).to eq(-90.0)
        expect(result.longitude).to eq(-180.0)
      end
    end

    context 'with invalid coordinates' do
      it 'raises ValidationError when latitude is missing' do
        service = described_class.new(user: user, latitude: nil, longitude: -122.4194)

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end

      it 'raises ValidationError when longitude is missing' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: nil)

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end

      it 'raises ValidationError when both coordinates are missing' do
        service = described_class.new(user: user, latitude: nil, longitude: nil)

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end

      it 'raises ValidationError when latitude is blank string' do
        service = described_class.new(user: user, latitude: '', longitude: -122.4194)

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end

      it 'raises ValidationError when longitude is blank string' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: '')

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end

      it 'raises ValidationError when latitude is whitespace' do
        service = described_class.new(user: user, latitude: '   ', longitude: -122.4194)

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Latitude and longitude are required')
      end
    end

    context 'transaction behavior' do
      it 'rolls back user update if history creation fails' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(UserLocation.new))

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError)

        user.reload
        expect(user.latitude).to be_nil
        expect(user.longitude).to be_nil
      end

      it 'commits both user and history updates together' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        service.update!

        user.reload
        expect(user.latitude).to eq(37.7749)
        expect(user.user_locations.count).to eq(1)
      end
    end

    context 'error handling' do
      it 'raises ValidationError when user update fails' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError, 'Failed to update location')
      end

      it 'logs error when user update fails' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
        allow(Rails.logger).to receive(:error)

        begin
          service.update!
        rescue UserLocationUpdateService::ValidationError
          # Expected error
        end

        expect(Rails.logger).to have_received(:error).with(/Failed to update location/)
      end

      it 'logs error when history creation fails' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        invalid_record = UserLocation.new
        allow(invalid_record).to receive_message_chain(:errors, :full_messages).and_return(['History error'])
        allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        begin
          service.update!
        rescue UserLocationUpdateService::ValidationError
          # Expected error
        end

        expect(Rails.logger).to have_received(:error).with(/Location history creation failed/)
      end

      it 'includes error details in ValidationError' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error 1', 'Error 2'])

        expect {
          service.update!
        }.to raise_error(UserLocationUpdateService::ValidationError) do |error|
          expect(error.details).to eq(['Error 1', 'Error 2'])
        end
      end
    end

    context 'persistence' do
      it 'persists coordinates to database' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        service.update!

        persisted_user = User.find(user.id)
        expect(persisted_user.latitude).to eq(37.7749)
        expect(persisted_user.longitude).to eq(-122.4194)
      end

      it 'persists location_updated_at to database' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        service.update!

        persisted_user = User.find(user.id)
        expect(persisted_user.location_updated_at).to be_present
      end
    end

    context 'updating existing location' do
      before do
        user.update!(latitude: 40.7128, longitude: -74.0060, location_updated_at: 1.day.ago)
      end

      it 'overwrites previous coordinates' do
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        result = service.update!

        expect(result.latitude).to eq(37.7749)
        expect(result.longitude).to eq(-122.4194)
      end

      it 'creates additional history record' do
        user.user_locations.create!(latitude: 40.7128, longitude: -74.0060, recorded_at: 1.day.ago)

        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        expect {
          service.update!
        }.to change { user.user_locations.count }.by(1)

        expect(user.user_locations.count).to eq(2)
      end

      it 'updates location_updated_at timestamp' do
        old_timestamp = user.location_updated_at
        service = described_class.new(user: user, latitude: 37.7749, longitude: -122.4194)

        result = service.update!

        expect(result.location_updated_at).to be > old_timestamp
      end
    end
  end

  describe 'ValidationError' do
    it 'is a StandardError' do
      error = UserLocationUpdateService::ValidationError.new('Test error')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Test error')
    end

    it 'stores error details' do
      error = UserLocationUpdateService::ValidationError.new('Test error', ['Detail 1', 'Detail 2'])

      expect(error.details).to eq(['Detail 1', 'Detail 2'])
    end

    it 'defaults to empty array for details' do
      error = UserLocationUpdateService::ValidationError.new('Test error')

      expect(error.details).to eq([])
    end
  end
end
