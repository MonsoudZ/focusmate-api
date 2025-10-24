module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user!
    end

    private

    def find_user!
      token = request.params["token"] || request.headers["Authorization"]&.split&.last

      if token.blank?
        reject_unauthorized_connection
        return
      end

      begin
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: "HS256")
        user_id = payload.first["user_id"]

        # Check token expiration
        if payload.first["exp"] && payload.first["exp"] < Time.current.to_i
          reject_unauthorized_connection
          return
        end

        User.find(user_id)
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        reject_unauthorized_connection
      end
    end
  end
end
