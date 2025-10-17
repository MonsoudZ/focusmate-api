module Api
  module V1
    class RecurringTemplatesController < ApplicationController
      before_action :set_template, only: [:show, :update, :destroy, :generate_instance, :instances]

      # GET /api/v1/recurring_templates
      def index
        @templates = Task.joins(:list)
                        .where(lists: { owner_id: current_user.id })
                        .templates
                        .includes(:list, :recurring_instances)
        
        render json: @templates.map { |t| RecurringTemplateSerializer.new(t).as_json }
      end

      # GET /api/v1/recurring_templates/:id
      def show
        render json: RecurringTemplateSerializer.new(@template, include_instances: true).as_json
      end

      # POST /api/v1/recurring_templates
      def create
        list = current_user.owned_lists.find(params[:list_id])
        
        @template = list.tasks.build(template_params)
        @template.creator = current_user
        @template.is_recurring = true
        @template.recurring_template_id = nil # Ensure it's a template, not instance
        
        if @template.save
          # Generate first instance immediately
          @template.generate_next_instance
          
          render json: RecurringTemplateSerializer.new(@template).as_json, status: :created
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/recurring_templates/:id
      def update
        if @template.update(template_params)
          # Update all future instances if certain fields changed
          if template_params[:title].present? || template_params[:description].present?
            @template.recurring_instances.incomplete.update_all(
              title: @template.title,
              description: @template.description
            )
          end
          
          render json: RecurringTemplateSerializer.new(@template).as_json
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/recurring_templates/:id
      def destroy
        # Deleting template also deletes all instances (via dependent: :destroy)
        @template.destroy
        head :no_content
      end

      # POST /api/v1/recurring_templates/:id/generate_instance
      def generate_instance
        instance = @template.generate_next_instance
        
        if instance
          render json: TaskSerializer.new(instance, current_user: current_user).as_json, status: :created
        else
          render json: { error: 'Could not generate instance' }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/recurring_templates/:id/instances
      def instances
        @instances = @template.recurring_instances
                             .includes(:escalation)
                             .order(due_at: :desc)
        
        render json: @instances.map { |i| TaskSerializer.new(i, current_user: current_user).as_json }
      end

      private

      def set_template
        @template = Task.joins(:list)
                       .where(lists: { owner_id: current_user.id })
                       .find(params[:id])
        
        unless @template.is_recurring? && @template.recurring_template_id.nil?
          render json: { error: 'Not a recurring template' }, status: :unprocessable_entity
        end
      end

      def template_params
        params.require(:recurring_template).permit(
          :title, :description, :priority, :can_be_snoozed,
          :notification_interval_minutes, :requires_explanation_if_missed,
          :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
          :location_based, :location_latitude, :location_longitude, :location_radius_meters,
          :location_name, :notify_on_arrival, :notify_on_departure,
          recurrence_days: []
        )
      end
    end
  end
end
