# app/controllers/api/v1/lists_controller.rb
module Api
  module V1
    class ListsController < ApplicationController
      before_action :set_list, only: [:show, :update, :destroy]
      before_action :authorize_list, only: [:show, :update, :destroy]

      # GET /api/v1/lists
      def index
        # Get all list IDs the user has access to
        owned_list_ids = current_user.owned_lists.pluck(:id)
        shared_list_ids = ListShare.where(user_id: current_user.id, status: 'accepted').pluck(:list_id)
        all_list_ids = (owned_list_ids + shared_list_ids).uniq
        
        # Get lists from IDs
        @lists = List.where(id: all_list_ids)
        
        # Apply since filter if provided
        if params[:since].present?
          since_time = Time.parse(params[:since])
          @lists = @lists.modified_since(since_time)
        end
        
        # Separate active and deleted items
        active_lists = @lists.not_deleted
        deleted_lists = @lists.deleted
        
        # Build response with tombstones
        response_data = {
          lists: active_lists.map { |list| ListSerializer.new(list, current_user: current_user).as_json },
          tombstones: deleted_lists.map { |list| 
            {
              id: list.id,
              deleted_at: list.deleted_at.iso8601,
              type: 'list'
            }
          }
        }
        
        render json: response_data
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
          render_validation_errors(@list.errors)
        end
      end

      # PATCH /api/v1/lists/:id
      def update
        if @list.update(list_params)
          render json: ListSerializer.new(@list, current_user: current_user).as_json
        else
          render_validation_errors(@list.errors)
        end
      end

      # DELETE /api/v1/lists/:id
      def destroy
        @list.soft_delete!
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:id])
      end

      def authorize_list
        unless @list.viewable_by?(current_user)
          render_forbidden('Unauthorized')
        end
      end

      def list_params
        params.require(:list).permit(:name, :description)
      end
    end
  end
end