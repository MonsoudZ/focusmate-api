module Api
  module V1
    class SavedLocationsController < ApplicationController
      before_action :set_location, only: [ :show, :update, :destroy ]

      # GET /api/v1/saved_locations
      def index
        @locations = current_user.saved_locations
        render json: @locations.map { |loc| SavedLocationSerializer.new(loc).as_json }
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
          render json: { errors: @location.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/saved_locations/:id
      def update
        if @location.update(location_params)
          render json: SavedLocationSerializer.new(@location).as_json
        else
          render json: { errors: @location.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/saved_locations/:id
      def destroy
        @location.destroy
        head :no_content
      end

      private

      def set_location
        @location = current_user.saved_locations.find(params[:id])
      end

      def location_params
        params.require(:saved_location).permit(:name, :latitude, :longitude, :radius_meters, :address)
      end
    end
  end
end
