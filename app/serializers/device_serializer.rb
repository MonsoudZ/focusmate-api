# frozen_string_literal: true

class DeviceSerializer
  def initialize(device)
    @device = device
  end

  def as_json(*)
    {
      id: @device.id,
      platform: @device.platform,
      bundle_id: @device.bundle_id,
      device_name: @device.device_name,
      os_version: @device.os_version,
      app_version: @device.app_version,
      active: @device.active,
      last_seen_at: @device.last_seen_at,
      created_at: @device.created_at,
      updated_at: @device.updated_at
    }
  end
end
