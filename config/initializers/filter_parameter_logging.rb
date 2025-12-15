# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw,
  :email,
  :secret,
  :token,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :cvv,
  :cvc,
  # Additional security: filter device tokens and auth tokens
  :password,
  :password_confirmation,
  :access_token,
  :refresh_token,
  :authorization,
  :jwt,
  :api_key,
  :device_token,
  :fcm_token,
  :apns_token,
  :push_token
]
