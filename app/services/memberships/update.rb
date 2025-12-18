# frozen_string_literal: true

module Memberships
  class Update
    class Error < StandardError; end
    class BadRequest < Error; end

    ALLOWED_ROLES = %w[viewer editor].freeze

    def self.call!(membership:, actor:, role:)
      new(membership:, role:).call!
    end

    def initialize(membership:, role:)
      @membership = membership
      @role = role.to_s.downcase.strip.presence
    end

    def call!
      raise BadRequest, "role is required" if @role.blank?
      raise BadRequest, "Invalid role" unless ALLOWED_ROLES.include?(@role)

      @membership.update!(role: @role)
      @membership
    end
  end
end
