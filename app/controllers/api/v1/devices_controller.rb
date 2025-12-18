# frozen_string_literal: true

module Api
  module V1
    class DevicesController < ApplicationController
      include Paginatable

      before_action :authenticate_user!
      before_action :set_device, only: %i[show update destroy]
      before_action :validate_device_params, only: %i[create register update]
      before_action -> {
        validate_pagination_params(
          valid_order_fields: %w[created_at device_name platform last_seen_at]
        )
      }, only: :index

      # GET /api/v1/devices
      def index
        devices = build_devices_query

        if params[:page].present? || params[:per_page].present?
          result = apply_pagination(devices, default_per_page: 25, max_per_page: 50)

          render json: {
            devices: result[:paginated_query].map { |d| DeviceSerializer.new(d).as_json },
            pagination: result[:pagination_metadata]
          }
        else
          render json: devices.map { |d| DeviceSerializer.new(d).as_json }
        end
      end

      # GET /api/v1/devices/:id
      def show
        render json: DeviceSerializer.new(@device).as_json
      end

      # POST /api/v1/devices
      def create
        service = DeviceManagementService.new(user: current_user)
        attrs   = params[:device] || params

        token, platform = extract_token_and_platform(attrs)

        device = service.register(
          token:,
          platform:,
          locale: attrs[:locale],
          app_version: attrs[:app_version],
          device_name: attrs[:device_name],
          os_version: attrs[:os_version],
          bundle_id: attrs[:bundle_id],
          fcm_token: attrs[:fcm_token],
          apns_token: attrs[:apns_token]
        )

        render json: DeviceSerializer.new(device).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[Devices] Create failed: #{e.record.errors.full_messages}")
        render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
               status: :unprocessable_content
      end

      # POST /api/v1/devices/register (legacy)
      def register
        service = DeviceManagementService.new(user: current_user)

        token = params[:apns_token].presence || generate_dev_token
        platform = params[:platform].presence || "ios"

        device = service.register(
          token:,
          platform:,
          bundle_id: params[:bundle_id],
          fcm_token: params[:fcm_token],
          apns_token: params[:apns_token]
        )

        render json: DeviceSerializer.new(device).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[Devices] Legacy register failed: #{e.record.errors.full_messages}")
        render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
               status: :unprocessable_content
      end

      # PATCH/PUT /api/v1/devices/:id
      def update
        service = DeviceManagementService.new(user: current_user)

        device = service.update_device(device: @device, attributes: device_params)

        render json: DeviceSerializer.new(device).as_json
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[Devices] Update failed: #{e.record.errors.full_messages}")
        render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
               status: :unprocessable_content
      end

      # DELETE /api/v1/devices/:id
      def destroy
        @device.destroy!
        head :no_content
      end

      # POST /api/v1/devices/test_push
      def test_push
        device = current_user.devices.find(params[:device_id])
        service = DeviceManagementService.new(user: current_user)

        result = service.send_test_push(device:)

        if result[:success]
          render json: result
        else
          render json: { error: { message: result[:error] } }, status: :unprocessable_content
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: { message: "Resource not found" } }, status: :not_found
      end

      private

      def set_device
        @device = current_user.devices.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { message: "Resource not found" } }, status: :not_found
      end

      def device_params
        params.permit(
          :apns_token,
          :fcm_token,
          :platform,
          :bundle_id,
          :device_name,
          :os_version,
          :app_version,
          :locale
        )
      end

      def validate_device_params
        return if params[:device_name].blank? || params[:device_name].length <= 255

        render json: { error: { message: "Device name too long (maximum 255 characters)" } },
               status: :bad_request
      end

      def extract_token_and_platform(attrs)
        if attrs[:apns_token].present?
          [attrs[:apns_token], "ios"]
        elsif attrs[:fcm_token].present?
          [attrs[:fcm_token], "android"]
        else
          [generate_dev_token, "ios"]
        end
      end

      def generate_dev_token
        "dev_token_#{SecureRandom.hex(16)}"
      end

      def build_devices_query
        devices = current_user.devices

        if params[:platform].present?
          platform = params[:platform].to_s.downcase
          devices = devices.where(platform:) if %w[ios android].include?(platform)
        end

        if params[:active].present?
          active = ActiveModel::Type::Boolean.new.cast(params[:active])
          devices = devices.where(active:) unless active.nil?
        end

        if params[:search].present?
          q = "%#{params[:search]}%"
          devices = devices.where(
            "device_name ILIKE ? OR os_version ILIKE ? OR app_version ILIKE ?",
            q, q, q
          )
        end

        apply_ordering(
          devices,
          valid_columns: %w[device_name platform last_seen_at created_at],
          default_column: "created_at",
          default_direction: :desc
        )
      end
    end
  end
end
