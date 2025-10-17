require "apnotic"

class ApnsClient
  def initialize
    @connection = Apnotic::Connection.new(
      auth_method: :token,
      cert: OpenSSL::PKey.read(APNS_P8[:p8]),
      key_id: APNS_P8[:key_id],
      team_id: APNS_P8[:team_id],
      url: APNS_P8[:env] == "production" ? Apnotic::PRODUCTION_URL : Apnotic::DEVELOPMENT_URL
    )
  end

  def push(device_token:, title:, body:, payload: {})
    notification = Apnotic::Notification.new(device_token)
    notification.topic = APNS_P8[:bundle_id]
    notification.alert = { title: title, body: body }
    notification.sound = "default"
    notification.custom_payload = payload
    @connection.push(notification).tap { @connection.close }
  end
end
