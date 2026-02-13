# frozen_string_literal: true

RSpec.describe Device do
  let(:user) { create(:user) }
  let(:device) { create(:device, user: user) }

  describe 'validations' do
    it 'requires user' do
      device = build(:device, user: nil)
      expect(device).not_to be_valid
    end

    it 'requires platform' do
      device = build(:device, user: user, platform: nil)
      expect(device).not_to be_valid
    end

    it 'requires valid platform' do
      device = build(:device, user: user, platform: 'windows')
      expect(device).not_to be_valid
    end

    it 'requires bundle_id' do
      device = build(:device, user: user, bundle_id: nil)
      expect(device).not_to be_valid
    end

    it 'requires apns_token for ios' do
      device = build(:device, user: user, platform: 'ios', apns_token: nil)
      expect(device).not_to be_valid
    end

    it 'requires fcm_token for android' do
      device = Device.new(user: user, platform: 'android', bundle_id: 'com.intentia.app', apns_token: nil, fcm_token: nil)
      expect(device).not_to be_valid
      expect(device.errors[:fcm_token]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(device.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has ios scope' do
      ios_device = create(:device, user: user, platform: 'ios')
      android_device = create(:device, user: user, platform: 'android', apns_token: nil, fcm_token: 'fcm123')
      expect(Device.ios).to include(ios_device)
      expect(Device.ios).not_to include(android_device)
    end

    it 'has active scope' do
      active_device = create(:device, user: user, active: true)
      inactive_device = create(:device, user: user, active: false)
      expect(Device.active).to include(active_device)
      expect(Device.active).not_to include(inactive_device)
    end
  end

  describe 'methods' do
    it 'returns ios?' do
      ios_device = build(:device, platform: 'ios')
      expect(ios_device.ios?).to be true
    end

    it 'returns android?' do
      android_device = build(:device, platform: 'android')
      expect(android_device.android?).to be true
    end

    it 'returns push_token for ios' do
      ios_device = build(:device, platform: 'ios', apns_token: 'apns123')
      expect(ios_device.push_token).to eq('apns123')
    end

    it 'returns push_token for android' do
      android_device = build(:device, platform: 'android', fcm_token: 'fcm123')
      expect(android_device.push_token).to eq('fcm123')
    end
  end

  describe 'soft deletion' do
    it 'soft deletes device' do
      device.soft_delete!
      expect(device.deleted?).to be true
      expect(Device.all).not_to include(device)
    end

    it 'includes soft deleted with scope' do
      device.soft_delete!
      expect(Device.with_deleted).to include(device)
    end
  end
end
