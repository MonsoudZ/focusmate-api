# frozen_string_literal: true

class ListCreationService < ApplicationService
  PERMITTED_ATTRIBUTES = %i[name description visibility color].freeze

  def initialize(user:, params:)
    @user = user
    @attributes = normalize_params(params)
  end

  def call!
    validate_params!
    build_list
    save_list!
    @list
  end

  private

  def validate_params!
    if @attributes.empty? || !@attributes.key?(:name)
      raise ApplicationError::Validation.new("Validation failed", details: { name: [ "can't be blank" ] })
    end
  end

  def build_list
    @list = @user.owned_lists.new(@attributes)
  end

  def save_list!
    unless @list.save
      raise ApplicationError::Validation.new("Validation failed", details: @list.errors.as_json)
    end
  end

  def normalize_params(params)
    source =
      case params
      when ActionController::Parameters
        params.permit(*PERMITTED_ATTRIBUTES).to_h
      when Hash
        params.with_indifferent_access.slice(*PERMITTED_ATTRIBUTES).to_h
      else
        {}
      end

    source
      .symbolize_keys
      .transform_values { |value| value.is_a?(String) ? value.strip : value }
  end
end
