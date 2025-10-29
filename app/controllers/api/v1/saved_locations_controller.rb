module Api
  module V1
    class SavedLocationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_location, only: [ :show, :update, :destroy ]
      before_action :validate_location_params, only: [ :create, :update ]

      # GET /api/v1/saved_locations
      def index
        begin
          locations = build_locations_query
          render json: locations.map { |loc| SavedLocationSerializer.new(loc).as_json }
        rescue => e
          Rails.logger.error "SavedLocationsController#index error: #{e.message}"
          render json: { error: { message: "Failed to retrieve saved locations" } },
                 status: :internal_server_error
        end
      end

      # GET /api/v1/saved_locations/:id
      def show
        begin
          render json: SavedLocationSerializer.new(@location).as_json
        rescue => e
          Rails.logger.error "SavedLocationsController#show error: #{e.message}"
          render json: { error: { message: "Failed to retrieve saved location" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/saved_locations
      def create
        begin
          @location = current_user.saved_locations.build(location_params)

          if @location.save
            render json: SavedLocationSerializer.new(@location).as_json, status: :created
          else
            Rails.logger.error "Location creation validation failed: #{@location.errors.full_messages}"
            render json: {
              error: {
                message: "Validation failed",
                details: @location.errors.as_json
              }
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "SavedLocationsController#create error: #{e.message}"
          render json: { error: { message: "Failed to create saved location" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/saved_locations/:id
      def update
        begin
          if @location.update(location_params)
            render json: SavedLocationSerializer.new(@location).as_json
          else
            Rails.logger.error "Location update validation failed: #{@location.errors.full_messages}"
            render json: {
              error: {
                message: "Validation failed",
                details: @location.errors.as_json
              }
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "SavedLocationsController#update error: #{e.message}"
          render json: { error: { message: "Failed to update saved location" } },
                 status: :internal_server_error
        end
      end

      # DELETE /api/v1/saved_locations/:id
      def destroy
        begin
          @location.destroy
          head :no_content
        rescue => e
          Rails.logger.error "SavedLocationsController#destroy error: #{e.message}"
          render json: { error: { message: "Failed to delete saved location" } },
                 status: :internal_server_error
        end
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
        begin
          @location = current_user.saved_locations.find(params[:id])
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.warn "Saved location not found: #{params[:id]}"
          render json: { error: { message: "Resource not found" } },
                 status: :not_found
        rescue => e
          Rails.logger.error "Error finding saved location: #{e.message}"
          render json: { error: { message: "Failed to retrieve saved location" } },
                 status: :internal_server_error
        end
      end

      def validate_location_params
        # Validate latitude if present
        if params[:saved_location] && params[:saved_location][:latitude].present?
          latitude = params[:saved_location][:latitude].to_f
          unless latitude.between?(-90, 90)
            render json: {
              error: {
                message: "Validation failed",
                details: { latitude: [ "must be between -90 and 90" ] }
              }
            }, status: :unprocessable_entity
            return
          end
        end

        # Validate longitude if present
        if params[:saved_location] && params[:saved_location][:longitude].present?
          longitude = params[:saved_location][:longitude].to_f
          unless longitude.between?(-180, 180)
            render json: {
              error: {
                message: "Validation failed",
                details: { longitude: [ "must be between -180 and 180" ] }
              }
            }, status: :unprocessable_entity
            return
          end
        end

        # Validate radius_meters if present
        if params[:saved_location] && params[:saved_location][:radius_meters].present?
          radius = params[:saved_location][:radius_meters].to_f
          unless radius > 0 && radius <= 10000
            render json: {
              error: {
                message: "Validation failed",
                details: { radius_meters: [ "must be between 1 and 10000 meters" ] }
              }
            }, status: :unprocessable_entity
            return
          end
        end

        # Validate name length if present
        if params[:saved_location] && params[:saved_location][:name].present?
          name = params[:saved_location][:name].to_s.strip
          if name.length > 255
            render json: {
              error: {
                message: "Validation failed",
                details: { name: [ "is too long (maximum 255 characters)" ] }
              }
            }, status: :unprocessable_entity
            return
          end
        end

        # Validate address length if present
        if params[:saved_location] && params[:saved_location][:address].present?
          address = params[:saved_location][:address].to_s.strip
          if address.length > 500
            render json: {
              error: {
                message: "Validation failed",
                details: { address: [ "is too long (maximum 500 characters)" ] }
              }
            }, status: :unprocessable_entity
            nil
          end
        end
      end

      def location_params
        params.require(:saved_location).permit(:name, :latitude, :longitude, :radius_meters, :address)
      end
    end
  end
end
