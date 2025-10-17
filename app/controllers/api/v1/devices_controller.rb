module Api
  module V1
    class DevicesController < ApplicationController
      # POST /api/v1/devices/register
      def register
        device = current_user.devices.find_or_initialize_by(
          apns_token: params[:apns_token]
        )
        
        device.assign_attributes(
          platform: params[:platform] || 'ios',
          bundle_id: params[:bundle_id]
        )
        
        if device.save
          render json: { device: DeviceSerializer.new(device).as_json }, status: :created
        else
          render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/devices/:id
      def destroy
        device = current_user.devices.find(params[:id])
        device.destroy
        head :no_content
      end
    end
  end
end
