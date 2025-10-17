class DeviceSerializer
  attr_reader :device

  def initialize(device)
    @device = device
  end

  def as_json
    {
      id: device.id,
      device_type: device.device_type,
      device_token: device.device_token,
      platform: device.platform,
      app_version: device.app_version,
      last_seen_at: device.last_seen_at&.iso8601,
      created_at: device.created_at.iso8601,
      updated_at: device.updated_at.iso8601
    }
  end
end