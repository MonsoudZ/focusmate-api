# frozen_string_literal: true

class InvitesController < ActionController::Base
  layout "invite"

  # GET /invite/:code
  def show
    @invite = ListInvite.includes(:list, :inviter).find_by(code: params[:code].upcase)

    if @invite.nil?
      @error = "This invite link is invalid"
    elsif @invite.expired?
      @error = "This invite link has expired"
    elsif @invite.exhausted?
      @error = "This invite link has reached its usage limit"
    end

    @app_store_url = ENV["APP_STORE_URL"]
    # UNIVERSAL_LINK_DOMAIN is for iOS/Android deep links (requires apple-app-site-association)
    # Falls back to APP_URL if not set
    universal_domain = ENV["UNIVERSAL_LINK_DOMAIN"] || ENV.fetch("APP_URL", "https://focusmate.app")
    @universal_link = "#{universal_domain}/invite/#{params[:code]}"
  end
end
