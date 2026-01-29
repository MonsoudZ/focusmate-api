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

    @app_store_url = ENV.fetch("APP_STORE_URL", "https://apps.apple.com/app/focusmate")
    @universal_link = "#{ENV.fetch('APP_URL', 'https://focusmate.app')}/invite/#{params[:code]}"
  end
end
