# frozen_string_literal: true

require "flipper"
require "flipper/adapters/active_record"

# Configure Flipper to use ActiveRecord adapter
Flipper.configure do |config|
  config.default do
    # Use ActiveRecord adapter for feature flags
    adapter = Flipper::Adapters::ActiveRecord.new
    Flipper.new(adapter)
  end
end
