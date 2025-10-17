module Api
  module V1
    class ListSharesController < ApplicationController
      before_action :set_list
      before_action :authorize_list_owner

      # GET /api/v1/lists/:list_id/shares
      def index
        @shares = @list.memberships.where.not(coaching_relationship_id: nil)
                                    .includes(coaching_relationship: [:coach])
        
        render json: @shares.map { |share| ListShareSerializer.new(share).as_json }
      end

      # POST /api/v1/lists/:list_id/shares
      def create
        coach = User.find(params[:coach_id])
        relationship = current_user.coaching_relationship_with(coach)
        
        unless relationship&.active?
          return render json: { error: 'No active coaching relationship found' }, status: :unprocessable_entity
        end

        @share = @list.memberships.build(
          user: coach,
          coaching_relationship: relationship,
          can_add_items: params[:can_add_items] || true,
          receive_overdue_alerts: params[:receive_overdue_alerts] || true
        )

        if @share.save
          NotificationService.list_shared(@list, coach)
          render json: ListShareSerializer.new(@share).as_json, status: :created
        else
          render json: { errors: @share.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id/update_permissions
      def update_permissions
        @share = @list.memberships.find(params[:id])

        if @share.update(share_params)
          render json: ListShareSerializer.new(@share).as_json
        else
          render json: { errors: @share.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/lists/:list_id/shares/:id
      def destroy
        @share = @list.memberships.find(params[:id])
        coach = @share.user
        @share.destroy
        
        # Send notification to coach about list being unshared
        NotificationService.list_unshared(@list, coach)
        
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def authorize_list_owner
        unless @list.owner == current_user
          render json: { error: 'Only list owner can manage sharing' }, status: :forbidden
        end
      end

      def share_params
        params.permit(:can_add_items, :receive_overdue_alerts)
      end
    end
  end
end
