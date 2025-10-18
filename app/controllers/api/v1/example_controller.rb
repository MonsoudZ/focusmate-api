# frozen_string_literal: true

module Api
  module V1
    class ExampleController < ApplicationController
      before_action :authenticate_user!
      before_action :set_example, only: [ :show, :update, :destroy ]
      after_action :verify_authorized, except: [ :index, :create ]

      # GET /api/v1/examples
      def index
        @examples = Example.all
        authorize @examples
        render json: @examples
      end

      # GET /api/v1/examples/:id
      def show
        authorize @example
        render json: @example
      end

      # POST /api/v1/examples
      def create
        @example = Example.new(example_params)
        authorize @example

        if @example.save
          # Example of using Flipper feature flag
          if Flipper.enabled?(:new_feature, current_user)
            ExampleJob.perform_later("New feature enabled for user #{current_user.id}")
          end

          render json: @example, status: :created
        else
          render json: { errors: @example.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/examples/:id
      def update
        authorize @example

        if @example.update(example_params)
          render json: @example
        else
          render json: { errors: @example.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/examples/:id
      def destroy
        authorize @example
        @example.destroy
        head :no_content
      end

      private

      def set_example
        @example = Example.find(params[:id])
      end

      def example_params
        params.require(:example).permit(:name, :description)
      end
    end
  end
end
