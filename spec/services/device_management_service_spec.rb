# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviceManagementService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user:) }

  describe '#register' do
    it 'registers idempotently' do
      d1 = service.register(token: 'abc', platform: 'ios')
      d2 = service.register(token: 'abc', platform: 'ios')
      expect(d1.id).to eq(d2.id)
    end

    it 'registers iOS device with APNS token' do
      device = service.register(
        token: 'apns_token_123',
        platform: 'ios',
        bundle_id: 'com.example.app',
        device_name: 'iPhone 15',
        os_version: '17.0',
        app_version: '1.0.0'
      )

      expect(device.apns_token).to eq('apns_token_123')
      expect(device.platform).to eq('ios')
      expect(device.bundle_id).to eq('com.example.app')
      expect(device.device_name).to eq('iPhone 15')
      expect(device.os_version).to eq('17.0')
      expect(device.app_version).to eq('1.0.0')
      expect(device.user).to eq(user)
    end

    it 'registers Android device with FCM token' do
      device = service.register(
        token: 'fcm_token_456',
        platform: 'android',
        fcm_token: 'fcm_token_456',
        device_name: 'Pixel 8',
        os_version: '14',
        app_version: '1.0.0'
      )

      expect(device.fcm_token).to eq('fcm_token_456')
      expect(device.platform).to eq('android')
      expect(device.user).to eq(user)
    end

    it 'updates last_seen_at on registration' do
      device = service.register(token: 'test_token', platform: 'ios')
      expect(device.last_seen_at).to be_present
    end

    it 'handles validation errors gracefully' do
      expect {
        service.register(token: '', platform: 'ios')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#touch!' do
    let!(:device) { create(:device, user:, apns_token: 'test_token', platform: 'ios') }

    it 'updates last_seen_at for iOS device' do
      service.touch!(token: 'test_token', platform: 'ios')
      expect(device.reload.last_seen_at).to be_present
    end

    it 'updates last_seen_at for Android device' do
      android_device = create(:device, user:, fcm_token: 'fcm_token', platform: 'android')
      service.touch!(token: 'fcm_token', platform: 'android')
      expect(android_device.reload.last_seen_at).to be_present
    end
  end

  describe '#revoke' do
    let!(:device) { create(:device, user:, apns_token: 'test_token', platform: 'ios') }

    it 'deletes iOS device by APNS token' do
      expect {
        service.revoke(token: 'test_token', platform: 'ios')
      }.to change { Device.count }.by(-1)
    end

    it 'deletes Android device by FCM token' do
      android_device = create(:device, user:, fcm_token: 'fcm_token', platform: 'android')
      expect {
        service.revoke(token: 'fcm_token', platform: 'android')
      }.to change { Device.count }.by(-1)
    end
  end

  describe '#find_by_token' do
    let!(:device) { create(:device, user:, apns_token: 'test_token', platform: 'ios') }

    it 'finds iOS device by APNS token' do
      found_device = service.find_by_token(token: 'test_token', platform: 'ios')
      expect(found_device).to eq(device)
    end

    it 'finds Android device by FCM token' do
      android_device = create(:device, user:, fcm_token: 'fcm_token', platform: 'android')
      found_device = service.find_by_token(token: 'fcm_token', platform: 'android')
      expect(found_device).to eq(android_device)
    end
  end

  describe '#list' do
    let!(:device1) { create(:device, user:, platform: 'ios') }
    let!(:device2) { create(:device, user:, platform: 'android') }

    it 'returns all user devices' do
      devices = service.list
      expect(devices).to include(device1, device2)
    end
  end

  describe '#update_device' do
    let!(:device) { create(:device, user:, platform: 'ios') }

    it 'updates device attributes' do
      updated_device = service.update_device(
        device: device,
        attributes: { device_name: 'Updated iPhone', os_version: '17.1' }
      )

      expect(updated_device.device_name).to eq('Updated iPhone')
      expect(updated_device.os_version).to eq('17.1')
    end

    it 'updates last_seen_at on update' do
      service.update_device(device: device, attributes: { device_name: 'Updated' })
      expect(device.reload.last_seen_at).to be_present
    end
  end

  describe '#send_test_push' do
    let!(:device) { create(:device, user:, platform: 'ios') }

    it 'sends test push notification successfully' do
      allow(NotificationService).to receive(:send_test_notification).and_return(true)

      result = service.send_test_push(device: device)

      expect(result[:success]).to be true
      expect(result[:message]).to include('Test push notification sent successfully')
      expect(result[:device_id]).to eq(device.id)
      expect(result[:platform]).to eq('ios')
    end

    it 'handles push notification errors gracefully' do
      allow(NotificationService).to receive(:send_test_notification).and_raise(StandardError.new('Push failed'))

      result = service.send_test_push(device: device)

      expect(result[:success]).to be false
      expect(result[:error]).to include('Push failed')
    end
  end
end
