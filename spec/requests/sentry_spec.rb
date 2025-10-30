# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentry Integration', type: :request do
  describe 'Error tracking' do
    it 'captures exceptions and sends to Sentry' do
      # Mock Sentry with_scope to verify it's called
      scope = double('scope').as_null_object
      allow(Sentry).to receive(:with_scope).and_yield(scope)
      expect(Sentry).to receive(:capture_exception).with(an_instance_of(StandardError))

      # Create a test controller that raises an exception
      test_controller = Class.new(ApplicationController) do
        # Skip authentication for this test
        skip_before_action :authenticate_user!

        def test_error
          raise StandardError, "Test error for Sentry"
        end

        # Override should_track_error? to allow tracking in test environment
        def should_track_error?(severity)
          true
        end
      end

      # Add a test route
      Rails.application.routes.draw do
        get '/test_error', to: test_controller.action(:test_error)
      end

      get '/test_error'

      # Clean up the route
      Rails.application.reload_routes!
    end
  end
end
