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
      device_name: device.device_name,
      user: {
        id: device.user.id,
        email: device.user.email
      },
      created_at: device.created_at.iso8601,
      updated_at: device.updated_at.iso8601
    }
  end
end
