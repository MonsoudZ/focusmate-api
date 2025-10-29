module Api
  module V1
    class SavedLocationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_location, only: [ :show, :update, :destroy ]
      before_action :validate_location_params, only: [ :create, :update ]

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
            error: {
              message: "Validation failed",
              details: @location.errors.as_json
            }
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
            error: {
              message: "Validation failed",
              details: @location.errors.as_json
            }
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
