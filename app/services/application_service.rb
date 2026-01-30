# frozen_string_literal: true

# Base class for all service objects.
#
# Provides a standardized interface for service objects:
# - Class method .call!(...) for convenient one-liner usage
# - Instance method #call! for the actual implementation
#
# @example Basic usage
#   class MyService < ApplicationService
#     def initialize(user:, params:)
#       @user = user
#       @params = params
#     end
#
#     def call!
#       # implementation
#     end
#   end
#
#   # Usage
#   MyService.call!(user: current_user, params: params)
#
# @example With multiple entry points
#   class TaskCompletionService < ApplicationService
#     def complete!
#       # ...
#     end
#
#     def uncomplete!
#       # ...
#     end
#
#     # Define custom class methods for different actions
#     def self.complete!(...)
#       new(...).complete!
#     end
#
#     def self.uncomplete!(...)
#       new(...).uncomplete!
#     end
#   end
#
class ApplicationService
  # Class method that instantiates the service and calls #call!
  # Passes all arguments to the initializer.
  def self.call!(...)
    new(...).call!
  end

  # Override this method in subclasses to implement the service logic.
  # @raise [NotImplementedError] if not overridden and called
  def call!
    raise NotImplementedError, "#{self.class}#call! must be implemented"
  end
end
