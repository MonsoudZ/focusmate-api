class ListShareMailer < ApplicationMailer
  default from: "noreply@focusmate.com"

  def invited_email
    @list_share = params[:list_share]
    @list = @list_share.list
    @accept_url = "#{ENV.fetch('APP_WEB_BASE', 'http://localhost:3000')}/accept?token=#{@list_share.invitation_token}"
    mail to: @list_share.email, subject: "You've been invited to a list"
  end

  def added_email
    @list_share = params[:list_share]
    @list = @list_share.list
    mail to: @list_share.email, subject: "You've been added to a list"
  end
end
