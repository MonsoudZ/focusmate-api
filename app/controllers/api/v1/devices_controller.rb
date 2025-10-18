module Api
  module V1
    class DevicesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_device, only: [:show, :update, :destroy]

      # GET /api/v1/devices
      def index
        @devices = current_user.devices.includes(:user)
        render json: @devices.map { |device| DeviceSerializer.new(device).as_json }
      end

      # GET /api/v1/devices/:id
      def show
        render json: DeviceSerializer.new(@device).as_json
      end

      # POST /api/v1/devices
      def create
        @device = current_user.devices.build(device_params)
        
        if @device.save
          render json: DeviceSerializer.new(@device).as_json, status: :created
        else
          render json: { errors: @device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/devices/register (legacy endpoint)
      def register
        @device = current_user.devices.find_or_initialize_by(
          apns_token: params[:apns_token]
        )
        
        @device.assign_attributes(
          platform: params[:platform] || 'ios',
          bundle_id: params[:bundle_id]
        )
        
        if @device.save
          render json: DeviceSerializer.new(@device).as_json, status: :created
        else
          render json: { errors: @device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/devices/:id
      def update
        if @device.update(device_params)
          render json: DeviceSerializer.new(@device).as_json
        else
          render json: { errors: @device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/devices/:id
      def destroy
        @device.destroy
        head :no_content
      end

      # POST /api/v1/devices/test_push
      def test_push
        device = current_user.devices.find(params[:device_id])
        
        # Send a test push notification
        begin
          NotificationService.send_test_notification(
            current_user,
            "Test Push: This is a test push notification from the API"
          )
          
          render json: { 
            message: "Test push notification sent successfully",
            device_id: device.id,
            platform: device.platform
          }
        rescue => e
          render json: { 
            error: "Failed to send test push: #{e.message}" 
          }, status: :unprocessable_entity
        end
      end

      private

      def set_device
        @device = current_user.devices.find(params[:id])
      end

      def device_params
        params.require(:device).permit(:apns_token, :platform, :bundle_id)
      end
    end
  end
end
