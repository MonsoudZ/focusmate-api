# frozen_string_literal: true

module Health
  module Checks
    class ExternalApis < Base
      def message = "External APIs"

      private

      def run
        # Fill this in when you actually have external dependencies.
        { configured: false }
      end
    end
  end
end
