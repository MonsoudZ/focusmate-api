# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Device, type: :model do
  let(:user) { create(:user) }
  let(:device) { build(:device, user: user, apns_token: SecureRandom.hex(32), platform: "ios", bundle_id: "com.focusmate.app") }

  describe 'validations' do
    it 'belongs to user' do
      expect(device).to be_valid
      expect(device.user).to eq(user)
    end

    it 'requires apns_token' do
      device.apns_token = nil
      expect(device).not_to be_valid
      expect(device.errors[:apns_token]).to include("can't be blank")
    end

    it 'validates unique apns_token' do
      device.save!

      duplicate_device = build(:device, user: user, apns_token: device.apns_token, platform: "ios", bundle_id: "com.focusmate.app")
      expect(duplicate_device).not_to be_valid
      expect(duplicate_device.errors[:apns_token]).to include("has already been taken")
    end

    it 'requires platform' do
      device.platform = nil
      expect(device).not_to be_valid
      expect(device.errors[:platform]).to include("can't be blank")
    end

    it 'validates platform inclusion' do
      device.platform = "invalid_platform"
      expect(device).not_to be_valid
      expect(device.errors[:platform]).to include("is not included in the list")
    end

    it 'requires bundle_id' do
      device.bundle_id = nil
      expect(device).not_to be_valid
      expect(device.errors[:bundle_id]).to include("can't be blank")
    end

    it 'validates bundle_id format' do
      device.bundle_id = "invalid_bundle_id"
      expect(device).not_to be_valid
      expect(device.errors[:bundle_id]).to include("is invalid")
    end

    it 'validates apns_token format' do
      device.apns_token = "invalid_token"
      expect(device).not_to be_valid
      expect(device.errors[:apns_token]).to include("is invalid")
    end

    it 'validates fcm_token format when present' do
      device.fcm_token = "invalid_fcm_token"
      expect(device).not_to be_valid
      expect(device.errors[:fcm_token]).to include("is invalid")
    end

    it 'allows nil fcm_token' do
      device.fcm_token = nil
      expect(device).to be_valid
    end

    it 'validates device_name length' do
      device.device_name = "a" * 256
      expect(device).not_to be_valid
      expect(device.errors[:device_name]).to include("is too long (maximum is 255 characters)")
    end

    it 'validates os_version length' do
      device.os_version = "a" * 51
      expect(device).not_to be_valid
      expect(device.errors[:os_version]).to include("is too long (maximum is 50 characters)")
    end

    it 'validates app_version length' do
      device.app_version = "a" * 51
      expect(device).not_to be_valid
      expect(device.errors[:app_version]).to include("is too long (maximum is 50 characters)")
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(device.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has ios scope' do
      ios_device = create(:device, user: user, platform: "ios")
      android_device = create(:device, user: user, platform: "android")

      expect(Device.ios).to include(ios_device)
      expect(Device.ios).not_to include(android_device)
    end

    it 'has android scope' do
      ios_device = create(:device, user: user, platform: "ios")
      android_device = create(:device, user: user, platform: "android")

      expect(Device.android).to include(android_device)
      expect(Device.android).not_to include(ios_device)
    end

    it 'has active scope' do
      active_device = create(:device, user: user, active: true)
      inactive_device = create(:device, user: user, active: false)

      expect(Device.active).to include(active_device)
      expect(Device.active).not_to include(inactive_device)
    end

    it 'has inactive scope' do
      active_device = create(:device, user: user, active: true)
      inactive_device = create(:device, user: user, active: false)

      expect(Device.inactive).to include(inactive_device)
      expect(Device.inactive).not_to include(active_device)
    end
  end

  describe 'methods' do
    it 'checks if device is ios' do
      ios_device = create(:device, user: user, platform: "ios")
      android_device = create(:device, user: user, platform: "android")

      expect(ios_device.ios?).to be true
      expect(android_device.ios?).to be false
    end

    it 'checks if device is android' do
      ios_device = create(:device, user: user, platform: "ios")
      android_device = create(:device, user: user, platform: "android")

      expect(android_device.android?).to be true
      expect(ios_device.android?).to be false
    end

    it 'checks if device is active' do
      active_device = create(:device, user: user, active: true)
      inactive_device = create(:device, user: user, active: false)

      expect(active_device.active?).to be true
      expect(inactive_device.active?).to be false
    end

    it 'activates device' do
      device.active = false
      device.activate!
      expect(device.active).to be true
    end

    it 'deactivates device' do
      device.active = true
      device.deactivate!
      expect(device.active).to be false
    end

    it 'returns device summary' do
      device.device_name = "iPhone 12"
      device.os_version = "15.0"
      device.app_version = "1.0.0"

      summary = device.summary
      expect(summary).to include(:id, :platform, :device_name, :os_version, :app_version, :active)
    end

    it 'returns push token' do
      ios_device = create(:device, user: user, platform: "ios", apns_token: "ios_token")
      android_device = create(:device, user: user, platform: "android", fcm_token: "android_token")

      expect(ios_device.push_token).to eq("ios_token")
      expect(android_device.push_token).to eq("android_token")
    end

    it 'returns nil push token for unsupported platform' do
      device.platform = "web"
      expect(device.push_token).to be_nil
    end

    it 'updates last_seen_at when accessed' do
      device.save!
      original_time = device.last_seen_at
      sleep(0.1)
      device.touch
      expect(device.last_seen_at).to be > original_time
    end
  end

  describe 'callbacks' do
    it 'sets default active status before validation' do
      device.active = nil
      device.valid?
      expect(device.active).to be true
    end

    it 'does not override existing active status' do
      device.active = false
      device.valid?
      expect(device.active).to be false
    end

    it 'sets last_seen_at on create' do
      device.save!
      expect(device.last_seen_at).not_to be_nil
    end

    it 'updates last_seen_at on update' do
      device.save!
      original_time = device.last_seen_at
      sleep(0.1)
      device.update!(device_name: "Updated Device")
      expect(device.last_seen_at).to be > original_time
    end
  end

  describe 'soft deletion' do
    it 'soft deletes device' do
      device.save!
      device.soft_delete!
      expect(device.deleted?).to be true
      expect(device.deleted_at).not_to be_nil
    end

    it 'restores soft deleted device' do
      device.save!
      device.soft_delete!
      device.restore!
      expect(device.deleted?).to be false
      expect(device.deleted_at).to be_nil
    end

    it 'excludes soft deleted devices from default scope' do
      device.save!
      device.soft_delete!
      expect(Device.all).not_to include(device)
      expect(Device.with_deleted).to include(device)
    end
  end

  describe 'platform specific validations' do
    it 'requires apns_token for ios platform' do
      ios_device = build(:device, user: user, platform: "ios", apns_token: nil)
      expect(ios_device).not_to be_valid
      expect(ios_device.errors[:apns_token]).to include("can't be blank")
    end

    it 'requires fcm_token for android platform' do
      android_device = Device.new(user: user, platform: "android", fcm_token: nil, bundle_id: "com.focusmate.app")
      expect(android_device).not_to be_valid
      expect(android_device.errors[:fcm_token]).to include("can't be blank")
    end

    it 'allows nil apns_token for android platform' do
      android_device = build(:device, user: user, platform: "android", apns_token: nil, fcm_token: "valid_fcm_token")
      expect(android_device).to be_valid
    end

    it 'allows nil fcm_token for ios platform' do
      ios_device = build(:device, user: user, platform: "ios", apns_token: "valid_apns_token", fcm_token: nil)
      expect(ios_device).to be_valid
    end
  end

  describe 'token validation' do
    it 'validates apns_token format for ios' do
      valid_apns_token = "a" * 64
      invalid_apns_token = "invalid_token"

      ios_device = build(:device, user: user, platform: "ios", apns_token: valid_apns_token)
      expect(ios_device).to be_valid

      ios_device.apns_token = invalid_apns_token
      expect(ios_device).not_to be_valid
    end

    it 'validates fcm_token format for android' do
      valid_fcm_token = "a" * 163
      invalid_fcm_token = "invalid_token"

      android_device = build(:device, user: user, platform: "android", fcm_token: valid_fcm_token)
      expect(android_device).to be_valid

      android_device.fcm_token = invalid_fcm_token
      expect(android_device).not_to be_valid
    end
  end

  describe 'device management' do
    it 'finds device by token' do
      device.save!
      found_device = Device.find_by_token(device.apns_token)
      expect(found_device).to eq(device)
    end

    it 'returns nil for non-existent token' do
      found_device = Device.find_by_token("non_existent_token")
      expect(found_device).to be_nil
    end

    it 'checks if device is online' do
      device.last_seen_at = 1.minute.ago
      expect(device.online?).to be true

      device.last_seen_at = 1.hour.ago
      expect(device.online?).to be false
    end

    it 'returns device age' do
      device.save!
      expect(device.age).to be >= 0
    end

    it 'returns device status' do
      device.active = true
      device.last_seen_at = 1.minute.ago
      expect(device.status).to eq("online")

      device.active = false
      expect(device.status).to eq("offline")

      device.active = true
      device.last_seen_at = 1.hour.ago
      expect(device.status).to eq("idle")
    end
  end
end
