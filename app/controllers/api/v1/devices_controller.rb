# frozen_string_literal: true

module Api
  module V1
    class DevicesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_device, only: [ :show, :update, :destroy ]
      before_action :validate_device_params, only: [ :create, :register, :update ]
      before_action :validate_pagination_params, only: [ :index ]

      # GET /api/v1/devices
      def index
        begin
          devices = build_devices_query

          # Check if pagination is requested
          if params[:page].present? || params[:per_page].present?
            # Apply pagination
            page = [ params[:page].to_i, 1 ].max
            per_page = [ params[:per_page].to_i, 1 ].max.clamp(1, 50)
            offset = (page - 1) * per_page

            paginated_devices = devices.limit(per_page).offset(offset)

            render json: {
              devices: paginated_devices.map { |device| DeviceSerializer.new(device).as_json },
              pagination: {
                page: page,
                per_page: per_page,
                total: devices.count,
                total_pages: (devices.count.to_f / per_page).ceil
              }
            }
          else
            # Return simple array for backward compatibility
            render json: devices.map { |device| DeviceSerializer.new(device).as_json }
          end
        rescue => e
          Rails.logger.error "DevicesController#index error: #{e.message}"
          render json: { error: { message: "Failed to retrieve devices" } },
                 status: :internal_server_error
        end
      end

      # GET /api/v1/devices/:id
      def show
        begin
          render json: DeviceSerializer.new(@device).as_json
        rescue => e
          Rails.logger.error "DevicesController#show error: #{e.message}"
          render json: { error: { message: "Failed to retrieve device" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/devices
      def create
        begin
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
                 status: :unprocessable_entity
        rescue => e
          Rails.logger.error "Device creation failed: #{e.message}"
          render json: { error: { message: "Failed to create device" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/devices/register (legacy endpoint)
      def register
        begin
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
                 status: :unprocessable_entity
        rescue => e
          Rails.logger.error "Device registration failed: #{e.message}"
          render json: { error: { message: "Failed to register device" } },
                 status: :internal_server_error
        end
      end

      # PATCH/PUT /api/v1/devices/:id
      def update
        begin
          service = DeviceManagementService.new(user: current_user)

          device = service.update_device(
            device: @device,
            attributes: device_params
          )

          render json: DeviceSerializer.new(device).as_json
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Device update validation failed: #{e.record.errors.full_messages}"
          render json: { error: { message: "Validation failed", details: e.record.errors.full_messages } },
                 status: :unprocessable_entity
        rescue => e
          Rails.logger.error "Device update failed: #{e.message}"
          render json: { error: { message: "Failed to update device" } },
                 status: :internal_server_error
        end
      end

      # DELETE /api/v1/devices/:id
      def destroy
        begin
          @device.destroy
          head :no_content
        rescue => e
          Rails.logger.error "Device deletion failed: #{e.message}"
          render json: { error: { message: "Failed to delete device" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/devices/test_push
      def test_push
        begin
          device = current_user.devices.find(params[:device_id])
          service = DeviceManagementService.new(user: current_user)

          result = service.send_test_push(device: device)

          if result[:success]
            render json: result
          else
            render json: { error: { message: result[:error] } }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: { message: "Resource not found" } }, status: :not_found
        rescue => e
          Rails.logger.error "Test push failed: #{e.message}"
          render json: { error: { message: "Failed to send test push" } },
                 status: :internal_server_error
        end
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

        # Apply ordering
        order_by = params[:order_by] || "created_at"
        order_direction = params[:order_direction]&.downcase == "asc" ? "asc" : "desc"

        case order_by
        when "device_name"
          devices = devices.order("device_name #{order_direction}")
        when "platform"
          devices = devices.order("platform #{order_direction}")
        when "last_seen_at"
          devices = devices.order("last_seen_at #{order_direction}")
        else
          devices = devices.order("created_at #{order_direction}")
        end

        devices
      end

      def validate_pagination_params
        # Validate page parameter
        if params[:page].present? && params[:page].to_i < 1
          render json: { error: { message: "Page parameter must be a positive integer" } },
                 status: :bad_request
          return
        end

        # Validate per_page parameter
        if params[:per_page].present? && (params[:per_page].to_i < 1 || params[:per_page].to_i > 50)
          render json: { error: { message: "Per page parameter must be between 1 and 50" } },
                 status: :bad_request
          return
        end

        # Validate order_by parameter
        if params[:order_by].present?
          valid_order_fields = %w[created_at device_name platform last_seen_at]
          unless valid_order_fields.include?(params[:order_by])
            render json: { error: { message: "Invalid order_by parameter" } },
                   status: :bad_request
            return
          end
        end

        # Validate order_direction parameter
        if params[:order_direction].present?
          unless %w[asc desc].include?(params[:order_direction].downcase)
            render json: { error: { message: "Order direction must be 'asc' or 'desc'" } },
                   status: :bad_request
            return
          end
        end

        # Validate search parameter length
        if params[:search].present? && params[:search].length > 100
          render json: { error: { message: "Search term too long (maximum 100 characters)" } },
                 status: :bad_request
          nil
        end
      end
    end
  end
end
