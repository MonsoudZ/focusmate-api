class DeviceSerializer
  attr_reader :device

  def initialize(device)
    @device = device
  end

  def as_json
    {
      id: device.id,
      device_type: device.device_type,
      device_name: device.device_name,
      created_at: device.created_at.iso8601
    }
  end
end
