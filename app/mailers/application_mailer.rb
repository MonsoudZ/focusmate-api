# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("DEVISE_MAILER_SENDER", "noreply@focusmate.app")
  layout "mailer"
end
