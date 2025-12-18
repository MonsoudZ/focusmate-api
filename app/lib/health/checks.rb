# frozen_string_literal: true

module Health
  class Checks
    def self.ready_checks
      [
        Checks::Database.new,
        Checks::Redis.new,
        Checks::Queue.new
      ]
    end

    def self.detailed_checks
      ready_checks + [
        Checks::Storage.new,
        Checks::ExternalApis.new
      ]
    end
  end
end
