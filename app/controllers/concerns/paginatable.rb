# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 50
  ORDER_DIRECTIONS = %w[asc desc].freeze

  # Apply pagination to an ActiveRecord::Relation
  #
  # @param query [ActiveRecord::Relation]
  # @param page [Integer, String, nil]
  # @param per_page [Integer, String, nil]
  # @param default_per_page [Integer]
  # @param max_per_page [Integer]
  # @return [Hash] { records:, pagination: }
  def paginate(query, page:, per_page:, default_per_page: DEFAULT_PER_PAGE, max_per_page: MAX_PER_PAGE)
    p = normalize_positive_int(page, fallback: 1)
    pp = normalize_per_page(per_page, default_per_page:, max_per_page:)

    offset = (p - 1) * pp

    total = query.count
    records = query.limit(pp).offset(offset)

    {
      records: records,
      pagination: {
        page: p,
        per_page: pp,
        total: total,
        total_pages: (total.to_f / pp).ceil
      }
    }
  end

  # Apply safe ordering with a whitelist
  #
  # @param query [ActiveRecord::Relation]
  # @param order_by [String, Symbol, nil]
  # @param order_direction [String, Symbol, nil]
  # @param valid_columns [Array<String, Symbol>]
  # @param default_column [String, Symbol]
  # @param default_direction [Symbol] :asc or :desc
  # @return [ActiveRecord::Relation]
  def order(query, order_by:, order_direction:, valid_columns:, default_column: :created_at, default_direction: :desc)
    cols = valid_columns.map(&:to_s)
    col = cols.include?(order_by.to_s) ? order_by.to_s : default_column.to_s

    dir =
      if ORDER_DIRECTIONS.include?(order_direction.to_s.downcase)
        order_direction.to_s.downcase.to_sym
      else
        default_direction
      end

    query.order(col => dir)
  end

  private

  def normalize_positive_int(value, fallback:)
    i = value.to_i
    i.positive? ? i : fallback
  end

  def normalize_per_page(value, default_per_page:, max_per_page:)
    pp = value.to_i
    pp = default_per_page if pp <= 0
    [ pp, max_per_page ].min
  end
end
