module Api
  module V1
    class SavedLocationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_location, only: [ :show, :update, :destroy ]
      before_action :validate_location_params, only: [ :create ]

      rescue_from ActionController::ParameterMissing do |exception|
        Rails.logger.error "Parameter missing: #{exception.message}"
        render json: { error: { message: exception.message } }, status: :internal_server_error
      end

      # GET /api/v1/saved_locations
      def index
        locations = build_locations_query
        render json: locations.map { |loc| SavedLocationSerializer.new(loc).as_json }
      end

      # GET /api/v1/saved_locations/:id
      def show
        render json: SavedLocationSerializer.new(@location).as_json
      end

      # POST /api/v1/saved_locations
      def create
        @location = current_user.saved_locations.build(location_params)

        if @location.save
          render json: SavedLocationSerializer.new(@location).as_json, status: :created
        else
          Rails.logger.error "Location creation validation failed: #{@location.errors.full_messages}"
          render json: {
            errors: @location.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/saved_locations/:id
      def update
        if @location.update(location_params)
          render json: SavedLocationSerializer.new(@location).as_json
        else
          Rails.logger.error "Location update validation failed: #{@location.errors.full_messages}"
          render json: {
            errors: @location.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/saved_locations/:id
      def destroy
        @location.destroy
        head :no_content
      end

      private

      def build_locations_query
        locations = current_user.saved_locations

        # Apply search filter if present
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          locations = locations.where("name ILIKE ? OR address ILIKE ?", search_term, search_term)
        end

        # Apply ordering
        order_by = params[:order_by] || "created_at"
        order_direction = params[:order_direction]&.downcase == "asc" ? "asc" : "desc"

        case order_by
        when "name"
          locations = locations.order("name #{order_direction}")
        when "updated_at"
          locations = locations.order("updated_at #{order_direction}")
        else
          locations = locations.order("created_at #{order_direction}")
        end

        locations
      end

      def set_location
        @location = current_user.saved_locations.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "Saved location not found: #{params[:id]}"
        render json: { error: { message: "Resource not found" } },
               status: :not_found
      end

      def validate_location_params
        errors = []

        # Validate latitude if present
        if params[:saved_location] && params[:saved_location][:latitude].present?
          latitude = params[:saved_location][:latitude].to_f
          unless latitude.between?(-90, 90)
            errors << "Latitude must be less than or equal to 90" if latitude > 90
            errors << "Latitude must be greater than or equal to -90" if latitude < -90
          end
        end

        # Validate longitude if present
        if params[:saved_location] && params[:saved_location][:longitude].present?
          longitude = params[:saved_location][:longitude].to_f
          unless longitude.between?(-180, 180)
            errors << "Longitude must be less than or equal to 180" if longitude > 180
            errors << "Longitude must be greater than or equal to -180" if longitude < -180
          end
        end

        # Validate radius_meters if present
        if params[:saved_location] && params[:saved_location][:radius_meters].present?
          radius = params[:saved_location][:radius_meters].to_f
          unless radius > 0 && radius <= 10000
            errors << "Radius meters must be greater than 0" if radius <= 0
            errors << "Radius meters must be less than or equal to 10000" if radius > 10000
          end
        end

        # Validate name length if present
        if params[:saved_location] && params[:saved_location][:name].present?
          name = params[:saved_location][:name].to_s
          if name.length > 255
            errors << "Name is too long (maximum is 255 characters)"
          end
        end

        # Validate address length if present
        if params[:saved_location] && params[:saved_location][:address].present?
          address = params[:saved_location][:address].to_s
          if address.length > 500
            errors << "Address is too long (maximum is 500 characters)"
          end
        end

        if errors.any?
          render json: { errors: errors }, status: :unprocessable_entity
          nil
        end
      end

      def location_params
        params.require(:saved_location).permit(:name, :latitude, :longitude, :radius_meters, :address)
      end
    end
  end
end
