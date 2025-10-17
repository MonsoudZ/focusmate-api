module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user!
    end

    private

    def find_user!
      token = request.params["token"] || request.headers["Authorization"]&.split&.last
      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      User.find(payload["sub"])
    rescue
      reject_unauthorized_connection
    end
  end
end
