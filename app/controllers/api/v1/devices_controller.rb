# frozen_string_literal: true

module Api
  module V1
    class DevicesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_device, only: [:show, :update, :destroy]

      # GET /api/v1/devices
      def index
        devices = DeviceManagementService.new(user: current_user).list
        render json: devices.map { |device| DeviceSerializer.new(device).as_json }
      end

      # GET /api/v1/devices/:id
      def show
        render json: DeviceSerializer.new(@device).as_json
      end

      # POST /api/v1/devices
      def create
        service = DeviceManagementService.new(user: current_user)
        
        # Handle nested parameters
        device_params = params[:device] || params
        
        # Determine token and platform
        token = device_params[:apns_token].present? ? device_params[:apns_token] : device_params[:fcm_token]
        platform = device_params[:platform] || (device_params[:apns_token].present? ? 'ios' : 'android')
        
        # Generate token if none provided
        if token.blank?
          token = "dev_token_#{SecureRandom.hex(16)}"
          platform = 'ios' # Default to iOS when generating token
        end

        device = service.register(
          token: token,
          platform: platform,
          locale: device_params[:locale],
          app_version: device_params[:app_version],
          device_name: device_params[:device_name],
          os_version: device_params[:os_version],
          bundle_id: device_params[:bundle_id],
          fcm_token: device_params[:fcm_token],
          apns_token: device_params[:apns_token]
        )

        render json: DeviceSerializer.new(device).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } }, status: :unprocessable_entity
      end

      # POST /api/v1/devices/register (legacy endpoint)
      def register
        service = DeviceManagementService.new(user: current_user)
        
        token = params[:apns_token] || "dev_token_#{SecureRandom.hex(16)}"
        platform = params[:platform] || 'ios'

        device = service.register(
          token: token,
          platform: platform,
          bundle_id: params[:bundle_id],
          fcm_token: params[:fcm_token],
          apns_token: params[:apns_token]
        )

        render json: DeviceSerializer.new(device).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH/PUT /api/v1/devices/:id
      def update
        service = DeviceManagementService.new(user: current_user)
        
        device = service.update_device(
          device: @device,
          attributes: device_params
        )

        render json: DeviceSerializer.new(device).as_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # DELETE /api/v1/devices/:id
      def destroy
        @device.destroy
        head :no_content
      end

      # POST /api/v1/devices/test_push
      def test_push
        device = current_user.devices.find(params[:device_id])
        service = DeviceManagementService.new(user: current_user)
        
        result = service.send_test_push(device: device)

        if result[:success]
          render json: result
        else
          render json: { error: { message: result[:error] } }, status: :unprocessable_entity
        end
      end

      private

      def set_device
        @device = current_user.devices.find(params[:id])
      end

      def device_params
        params.permit(:apns_token, :platform, :bundle_id, :fcm_token, :device_name, :os_version, :app_version, :locale)
      end
    end
  end
end
