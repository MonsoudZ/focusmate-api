# frozen_string_literal: true

module Health
  module Checks
    class Database < Base
      def message = "Database responsive"

      private

      def run
        ActiveRecord::Base.connection.execute("SELECT 1")
        nil
      end
    end
  end
end
