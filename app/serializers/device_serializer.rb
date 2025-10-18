class DeviceSerializer
  attr_reader :device

  def initialize(device)
    @device = device
  end

  def as_json
    {
      id: device.id,
      apns_token: device.apns_token,
      platform: device.platform,
      bundle_id: device.bundle_id,
      display_name: device.display_name,
      created_at: device.created_at.iso8601,
      updated_at: device.updated_at.iso8601
    }
  end
end