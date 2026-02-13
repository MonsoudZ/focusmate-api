# frozen_string_literal: true

class WellKnownController < ActionController::API
  # Apple App Site Association for universal links
  # GET /.well-known/apple-app-site-association
  def apple_app_site_association
    render json: {
      applinks: {
        apps: [],
        details: [
          {
            appID: ENV.fetch("APPLE_APP_ID", "CNK57345QT.com.monsoudzanaty.intentia"),
            paths: [ "/invite/*" ]
          }
        ]
      }
    }
  end
end
