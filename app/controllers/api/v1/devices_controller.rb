# frozen_string_literal: true

module Api
  module V1
    class DevicesController < BaseController
      before_action :set_device, only: %i[destroy]

      def create
        device = Devices::Upsert.call!(
          user: current_user,
          apns_token: device_params[:apns_token],
          device_name: device_params[:device_name],
          os_version: device_params[:os_version],
          app_version: device_params[:app_version],
          timezone: device_params[:timezone]
        )

        render json: { device: DeviceSerializer.new(device).as_json }, status: :created
      end

      def destroy
        @device.destroy!
        head :no_content
      end

      private

      def set_device
        @device = current_user.devices.find(params[:id])
      end

      def device_params
        params.require(:device).permit(
          :apns_token,
          :device_name,
          :os_version,
          :app_version,
          :timezone
        )
      end
    end
  end
end
