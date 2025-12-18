# frozen_string_literal: true

module Health
  module Checks
    class Storage < Base
      def message = "Storage configured"

      private

      def run
        if Rails.application.config.active_storage.service == :local
          path = Rails.root.join("storage")
          raise "Storage not writable" unless Dir.exist?(path) && File.writable?(path)
          { local: true, writable: true }
        else
          { local: false }
        end
      end
    end
  end
end
