# frozen_string_literal: true

module Apns
  module_function

  def client
    return nil unless Apns::Client.enabled?
    @client ||= Apns::Client.new
  end
end

