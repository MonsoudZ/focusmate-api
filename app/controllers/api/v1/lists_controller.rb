# app/controllers/api/v1/lists_controller.rb
module Api
  module V1
    class ListsController < ApplicationController
      before_action :set_list, only: [:show, :update, :destroy]
      before_action :authorize_list, only: [:show, :update, :destroy]

      # GET /api/v1/lists
      def index
        # Get lists user owns
        owned_lists = current_user.owned_lists
        
        # Get lists shared with user (accepted shares only)
        shared_list_ids = ListShare.where(user_id: current_user.id, status: 'accepted').pluck(:list_id)
        shared_lists = List.where(id: shared_list_ids)
        
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