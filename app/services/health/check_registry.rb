# frozen_string_literal: true

module Health
  class CheckRegistry
    def self.ready
      [
        Checks::Database.new,
        Checks::Redis.new,
        Checks::Queue.new
      ]
    end

    def self.detailed
      ready + [
        Checks::Storage.new,
        Checks::ExternalApis.new
      ]
    end
  end
end
