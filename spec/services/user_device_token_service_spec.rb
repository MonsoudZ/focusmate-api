require 'rails_helper'

RSpec.describe UserDeviceTokenService do
  let(:user) { create(:user) }

  describe '#update!' do
    context 'with device token type' do
      it 'updates device_token with valid token' do
        token = 'valid_device_token_123'
        service = described_class.new(user: user, token: token, token_type: :device)

        result = service.update!

        expect(result).to eq(user)
        expect(user.reload.device_token).to eq(token)
      end

      it 'updates device_token to nil for logout' do
        user.update!(device_token: 'existing_token')
        service = described_class.new(user: user, token: nil, token_type: :device)

        result = service.update!

        expect(result).to eq(user)
        expect(user.reload.device_token).to be_nil
      end

      it 'logs success with token preview' do
        token = 'very_long_token_that_should_be_truncated_in_logs'
        service = described_class.new(user: user, token: token, token_type: :device)

        allow(Rails.logger).to receive(:info)

        service.update!

        expect(Rails.logger).to have_received(:info).with(/Device token.*Updated for user ##{user.id}/)
      end

      it 'logs logout when token is nil' do
        service = described_class.new(user: user, token: nil, token_type: :device)

        allow(Rails.logger).to receive(:info)

        service.update!

        expect(Rails.logger).to have_received(:info).with(/nil \(logout\)/)
      end
    end

    context 'with FCM token type' do
      it 'updates fcm_token with valid token' do
        token = 'valid_fcm_token_456'
        service = described_class.new(user: user, token: token, token_type: :fcm)

        result = service.update!

        expect(result).to eq(user)
        expect(user.reload.fcm_token).to eq(token)
      end

      it 'updates fcm_token to nil for logout' do
        user.update!(fcm_token: 'existing_fcm_token')
        service = described_class.new(user: user, token: nil, token_type: :fcm)

        result = service.update!

        expect(result).to eq(user)
        expect(user.reload.fcm_token).to be_nil
      end

      it 'logs success with FCM token label' do
        token = 'fcm_token_789'
        service = described_class.new(user: user, token: token, token_type: :fcm)

        allow(Rails.logger).to receive(:info)

        service.update!

        expect(Rails.logger).to have_received(:info).with(/FCM token.*Updated for user ##{user.id}/)
      end
    end

    context 'with invalid tokens' do
      it 'raises ValidationError for whitespace-only device token' do
        service = described_class.new(user: user, token: '   ', token_type: :device)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'Device token is required')
      end

      it 'raises ValidationError for empty string device token' do
        service = described_class.new(user: user, token: '', token_type: :device)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'Device token is required')
      end

      it 'raises ValidationError for whitespace-only FCM token' do
        service = described_class.new(user: user, token: '   ', token_type: :fcm)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'FCM token is required')
      end

      it 'raises ValidationError for empty string FCM token' do
        service = described_class.new(user: user, token: '', token_type: :fcm)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'FCM token is required')
      end

      it 'raises ValidationError with tabs and spaces' do
        service = described_class.new(user: user, token: "\t  \t", token_type: :device)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'Device token is required')
      end
    end

    context 'token type defaults' do
      it 'defaults to device token type when not specified' do
        token = 'default_type_token'
        service = described_class.new(user: user, token: token)

        result = service.update!

        expect(user.reload.device_token).to eq(token)
        expect(user.fcm_token).to be_nil
      end
    end

    context 'with long tokens' do
      it 'updates with very long device token' do
        token = 'a' * 1000
        service = described_class.new(user: user, token: token, token_type: :device)

        result = service.update!

        expect(user.reload.device_token).to eq(token)
      end

      it 'truncates token preview in logs for long tokens' do
        token = 'a' * 100
        service = described_class.new(user: user, token: token, token_type: :device)

        allow(Rails.logger).to receive(:info)

        service.update!

        expect(Rails.logger).to have_received(:info) do |log_message|
          expect(log_message).to include('aaaaaa')
          expect(log_message).to include('...')
          expect(log_message.length).to be < token.length + 100
        end
      end
    end

    context 'persistence' do
      it 'persists device token to database' do
        token = 'persistent_token'
        service = described_class.new(user: user, token: token, token_type: :device)

        service.update!

        expect(User.find(user.id).device_token).to eq(token)
      end

      it 'persists FCM token to database' do
        token = 'persistent_fcm_token'
        service = described_class.new(user: user, token: token, token_type: :fcm)

        service.update!

        expect(User.find(user.id).fcm_token).to eq(token)
      end
    end

    context 'error handling' do
      it 'raises ValidationError when user update fails' do
        token = 'valid_token'
        service = described_class.new(user: user, token: token, token_type: :device)

        allow(user).to receive(:update).and_return(false)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'Failed to update device token')
      end

      it 'raises ValidationError with FCM token type when FCM update fails' do
        token = 'valid_token'
        service = described_class.new(user: user, token: token, token_type: :fcm)

        allow(user).to receive(:update).and_return(false)

        expect {
          service.update!
        }.to raise_error(UserDeviceTokenService::ValidationError, 'Failed to update fcm token')
      end
    end

    context 'with special characters in tokens' do
      it 'handles tokens with special characters' do
        token = 'token_with_special_chars_!@#$%^&*()'
        service = described_class.new(user: user, token: token, token_type: :device)

        result = service.update!

        expect(user.reload.device_token).to eq(token)
      end

      it 'handles tokens with unicode characters' do
        token = 'token_with_unicode_字符'
        service = described_class.new(user: user, token: token, token_type: :device)

        result = service.update!

        expect(user.reload.device_token).to eq(token)
      end
    end
  end

  describe 'ValidationError' do
    it 'is a StandardError' do
      error = UserDeviceTokenService::ValidationError.new('Test error')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Test error')
    end
  end
end
