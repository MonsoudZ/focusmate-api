# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  # Apply pagination to a query
  # @param query [ActiveRecord::Relation] The query to paginate
  # @param default_per_page [Integer] Default items per page (default: 25)
  # @param max_per_page [Integer] Maximum items per page (default: 50)
  # @return [Hash] { paginated_query:, pagination_metadata: }
  def apply_pagination(query, default_per_page: 25, max_per_page: 50)
    page = [params[:page].to_i, 1].max
    per_page = calculate_per_page(default_per_page, max_per_page)
    offset = (page - 1) * per_page

    paginated_query = query.limit(per_page).offset(offset)
    total_count = query.count

    {
      paginated_query: paginated_query,
      pagination_metadata: {
        page: page,
        per_page: per_page,
        total: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # Validate pagination parameters
  # @param valid_order_fields [Array<String>] Valid fields for ordering
  # @param max_per_page [Integer] Maximum items per page (default: 50)
  # @param max_search_length [Integer] Maximum search term length (default: 100)
  def validate_pagination_params(valid_order_fields: [], max_per_page: 50, max_search_length: 100)
    # Validate page parameter
    if params[:page].present? && params[:page].to_i < 1
      render json: { error: { message: "Page parameter must be a positive integer" } },
             status: :bad_request
      return false
    end

    # Validate per_page parameter
    if params[:per_page].present? && (params[:per_page].to_i < 1 || params[:per_page].to_i > max_per_page)
      render json: { error: { message: "Per page parameter must be between 1 and #{max_per_page}" } },
             status: :bad_request
      return false
    end

    # Validate order_by parameter
    if params[:order_by].present? && valid_order_fields.any?
      unless valid_order_fields.include?(params[:order_by])
        render json: { error: { message: "Invalid order_by parameter" } },
               status: :bad_request
        return false
      end
    end

    # Validate order_direction parameter
    if params[:order_direction].present?
      unless %w[asc desc].include?(params[:order_direction].downcase)
        render json: { error: { message: "Order direction must be 'asc' or 'desc'" } },
               status: :bad_request
        return false
      end
    end

    # Validate search parameter length
    if params[:search].present? && params[:search].length > max_search_length
      render json: { error: { message: "Search term too long (maximum #{max_search_length} characters)" } },
             status: :bad_request
      return false
    end

    true
  end

  # Apply ordering to a query
  # @param query [ActiveRecord::Relation] The query to order
  # @param valid_columns [Array<String>] Valid columns for ordering
  # @param default_column [String] Default column to order by (default: "created_at")
  # @param default_direction [Symbol] Default direction (:asc or :desc, default: :desc)
  # @return [ActiveRecord::Relation] Ordered query
  def apply_ordering(query, valid_columns:, default_column: "created_at", default_direction: :desc)
    order_by = params[:order_by] || default_column
    order_direction = params[:order_direction]&.downcase == "asc" ? :asc : default_direction

    # Whitelist valid columns
    column = valid_columns.include?(order_by) ? order_by.to_sym : default_column.to_sym

    # Use hash syntax to prevent SQL injection
    query.order(column => order_direction)
  end

  private

  def calculate_per_page(default_per_page, max_per_page)
    per_page = params[:per_page].to_i
    per_page = default_per_page if per_page <= 0
    [per_page, max_per_page].min
  end
end
