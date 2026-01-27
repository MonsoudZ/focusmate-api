# frozen_string_literal: true

module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: [ :show, :update, :destroy ]

      after_action :verify_authorized, except: [ :index ]
      after_action :verify_policy_scoped, only: [ :index ]

      # GET /api/v1/tags
      def index
        tags = policy_scope(Tag).alphabetical
        render json: { tags: tags.map { |t| TagSerializer.new(t).as_json } }, status: :ok
      end

      # GET /api/v1/tags/:id
      def show
        authorize @tag
        render json: TagSerializer.new(@tag).as_json, status: :ok
      end

      # POST /api/v1/tags
      def create
        tag = current_user.tags.build(tag_params)
        authorize tag

        if tag.save
          render json: TagSerializer.new(tag).as_json, status: :created
        else
          render json: { error: { message: tag.errors.full_messages.join(", ") } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/tags/:id
      def update
        authorize @tag

        if @tag.update(tag_params)
          render json: TagSerializer.new(@tag).as_json, status: :ok
        else
          render json: { error: { message: @tag.errors.full_messages.join(", ") } }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tags/:id
      def destroy
        authorize @tag
        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = current_user.tags.find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name, :color)
      end
    end
  end
end
