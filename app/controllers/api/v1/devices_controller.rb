# frozen_string_literal: true

module Api
  module V1
    class DevicesController < ApplicationController
      include Paginatable

      before_action :authenticate_user!
      before_action :set_device, only: [ :show, :update, :destroy ]
      before_action :validate_device_params, only: [ :create, :register, :update ]
      before_action -> { validate_pagination_params(valid_order_fields: %w[created_at device_name platform last_seen_at]) }, only: [ :index ]

      # GET /api/v1/devices
      def index
          devices = build_devices_query

          # Check if pagination is requested
          if params[:page].present? || params[:per_page].present?
            result = apply_pagination(devices, default_per_page: 25, max_per_page: 50)

            render json: {
              devices: result[:paginated_query].map { |device| DeviceSerializer.new(device).as_json },
              pagination: result[:pagination_metadata]
            }
          else
            # Return simple array for backward compatibility
            render json: devices.map { |device| DeviceSerializer.new(device).as_json }
          end
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
          platform = device_params[:platform] || (device_params[:apns_token].present? ? "ios" : "android")

          # Generate token if none provided
          if token.blank?
            token = "dev_token_#{SecureRandom.hex(16)}"
            platform = "ios" # Default to iOS when generating token
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
          Rails.logger.error "Device creation validation failed: #{e.record.errors.full_messages}"
          render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
                 status: :unprocessable_content
      end

      # POST /api/v1/devices/register (legacy endpoint)
      def register
          service = DeviceManagementService.new(user: current_user)

          token = params[:apns_token] || "dev_token_#{SecureRandom.hex(16)}"
          platform = params[:platform] || "ios"

          device = service.register(
            token: token,
            platform: platform,
            bundle_id: params[:bundle_id],
            fcm_token: params[:fcm_token],
            apns_token: params[:apns_token]
          )

          render json: DeviceSerializer.new(device).as_json, status: :created
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Device registration validation failed: #{e.record.errors.full_messages}"
          render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
                 status: :unprocessable_content
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
          Rails.logger.error "Device update validation failed: #{e.record.errors.full_messages}"
          render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
                 status: :unprocessable_content
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
        params.permit(:apns_token, :platform, :bundle_id, :fcm_token, :device_name, :os_version, :app_version, :locale)
      end

      def validate_device_params
        # Only validate basic format issues, let model validation handle the rest
        # This maintains backward compatibility with existing tests

        # Validate string length limits (these are hard limits that should be caught early)
        if params[:device_name].present? && params[:device_name].length > 255
          render json: { error: { message: "Device name too long (maximum 255 characters)" } },
                 status: :bad_request
          return
        end

        if params[:os_version].present? && params[:os_version].length > 50
          render json: { error: { message: "OS version too long (maximum 50 characters)" } },
                 status: :bad_request
          return
        end

        if params[:app_version].present? && params[:app_version].length > 50
          render json: { error: { message: "App version too long (maximum 50 characters)" } },
                 status: :bad_request
          nil
        end
      end

      def build_devices_query
        devices = current_user.devices.includes(:user)

        # Apply platform filter
        if params[:platform].present?
          platform = params[:platform].to_s.downcase
          if %w[ios android].include?(platform)
            devices = devices.where(platform: platform)
          end
        end

        # Apply active status filter
        if params[:active].present?
          active_value = case params[:active].to_s.downcase
          when "true", "1", "t", "yes", "y" then true
          when "false", "0", "f", "no", "n" then false
          else nil
          end
          devices = devices.where(active: active_value) unless active_value.nil?
        end

        # Apply search filter
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          devices = devices.where(
            "device_name ILIKE ? OR os_version ILIKE ? OR app_version ILIKE ?",
            search_term, search_term, search_term
          )
        end

        # Apply ordering using concern
        valid_columns = %w[device_name platform last_seen_at created_at]
        devices = apply_ordering(devices, valid_columns: valid_columns, default_column: "created_at", default_direction: :desc)

        devices
      end
    end
  end
end
