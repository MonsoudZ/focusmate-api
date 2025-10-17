# app/controllers/api/v1/lists_controller.rb
module Api
  module V1
    class ListsController < ApplicationController
      before_action :set_list, only: [:show, :update, :destroy]
      before_action :authorize_list, only: [:show, :update, :destroy]

      # GET /api/v1/lists
      def index
        # Return lists owned by user OR shared with user
        owned_lists = current_user.owned_lists
        shared_lists = current_user.client? ? [] : current_user.accessible_lists
        
        @lists = (owned_lists + shared_lists).uniq
        
        render json: @lists.map { |list| ListSerializer.new(list, current_user: current_user).as_json }
      end

      # GET /api/v1/lists/:id
      def show
        render json: ListSerializer.new(@list, current_user: current_user, include_tasks: true).as_json
      end

      # POST /api/v1/lists
      def create
        @list = current_user.owned_lists.build(list_params)
        
        if @list.save
          render json: ListSerializer.new(@list, current_user: current_user).as_json, status: :created
        else
          render json: { errors: @list.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:id
      def update
        if @list.update(list_params)
          render json: ListSerializer.new(@list, current_user: current_user).as_json
        else
          render json: { errors: @list.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/lists/:id
      def destroy
        @list.destroy
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:id])
      end

      def authorize_list
        unless @list.viewable_by?(current_user)
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end

      def list_params
        params.require(:list).permit(:name, :description)
      end
    end
  end
end