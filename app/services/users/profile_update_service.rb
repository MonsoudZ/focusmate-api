# frozen_string_literal: true

module Users
  class ProfileUpdateService
    def self.call!(user:, **attrs)
      new(user:, attrs:).call!
    end

    def initialize(user:, attrs:)
      @user = user
      @attrs = attrs.slice(:name, :timezone).compact
    end

    def call!
      return @user if @attrs.empty?

      validate_timezone! if @attrs[:timezone].present?

      @user.update!(@attrs)
      @user
    end

    private

    def validate_timezone!
      Time.find_zone!(@attrs[:timezone])
    rescue ArgumentError
      raise ApplicationError::Validation.new("Invalid timezone", details: { timezone: [ "is not a valid timezone" ] })
    end
  end
end
