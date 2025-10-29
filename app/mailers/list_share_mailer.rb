class ListShareMailer < ApplicationMailer
  default from: "noreply@focusmate.com"

  before_action :ensure_list_share_present
  before_action :set_list_and_accept_url, only: [ :invited_email, :invitation_email ]

  # Sent when a user is invited (pending acceptance)
  def invited_email
    mail to: @list_share.email, subject: "You've been invited to a list"
  end

  # Alias/duplicate of invited_email kept for compatibility with any callers
  def invitation_email
    mail to: @list_share.email, subject: "You've been invited to a list"
  end

  # Sent when a user is directly added to a list
  def added_email
    @list = @list_share.list
    mail to: @list_share.email, subject: "You've been added to a list"
  end

  # Sent when a user's access has been revoked
  def revocation_notification
    @list = @list_share.list
    mail to: @list_share.email, subject: "Your access to a list has been revoked"
  end

  private

  def ensure_list_share_present
    @list_share = params[:list_share]
    unless @list_share && @list_share.respond_to?(:email)
      raise ArgumentError, "list_share param with email is required"
    end
  end

  def set_list_and_accept_url
    @list = @list_share.list
    token = @list_share.respond_to?(:invitation_token) ? @list_share.invitation_token.to_s : ""
    base = ENV.fetch("APP_WEB_BASE", "http://localhost:3000")
    @accept_url = token.present? ? "#{base}/accept?token=#{CGI.escape(token)}" : nil
  end
end
