module Api
  module V1
    class RecurringTemplatesController < ApplicationController
      before_action :require_auth!                # ensure 401 happens first
      before_action :set_template, only: [ :show, :update, :destroy, :generate_instance, :instances ]

      # GET /api/v1/recurring_templates
      def index
        templates = base_scope
        templates = templates.where(list_id: params[:list_id]) if params[:list_id].present?
        render json: templates.map { |t| serialize_template(t) }, status: :ok
      end

      # GET /api/v1/recurring_templates/:id
      def show
        return not_found unless @template
        render json: serialize_template(@template, include_instances: true), status: :ok
      end

      # POST /api/v1/recurring_templates
      def create
        list = current_user&.owned_lists&.find_by(id: params[:list_id]) ||
               List.find_by(id: params[:list_id], user_id: current_user.id)   # 🔽 support factories that use user_id

        return render_error("List not found", :not_found) unless list

        attrs = template_params.to_h.symbolize_keys
        attrs[:note] = attrs.delete(:description) if attrs.key?(:description)
        attrs[:is_recurring] = true
        attrs[:recurring_template_id] = nil
        attrs[:strict_mode] ||= false

        # due_at is required by the model; seed it if missing
        attrs[:due_at] ||= begin
          if attrs[:recurrence_time].present?
            t = Time.zone.parse(attrs[:recurrence_time].to_s) rescue nil
            if t
              (Time.zone.today.to_time + t.seconds_since_midnight)
            else
              Time.current
            end
          else
            Time.current
          end
        end

        if attrs.key?(:recurrence_days)
          days = Array(attrs[:recurrence_days])
          # Convert day names to numbers if needed
          day_map = { "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3, "thursday" => 4, "friday" => 5, "saturday" => 6 }
          attrs[:recurrence_days] = days.map { |day| day_map[day.to_s.downcase] || day.to_i }
        end

        # Validate recurrence_time format before creating the task
        if attrs[:recurrence_time].present?
          time_str = attrs[:recurrence_time].to_s
          unless time_str.match?(/\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/)
            return render json: {
              error: {
                message: "Validation failed",
                details: { recurrence_time: [ "must be in HH:MM format" ] }
              }
            }, status: :unprocessable_entity
          end
        end

        template = list.tasks.new(attrs.merge(creator: current_user))

        if template.save
          render json: serialize_template(template), status: :created
        else
          Rails.logger.error "Template validation failed: #{template.errors.full_messages}"
          validation_error!(template)
        end
      end

      # PATCH /api/v1/recurring_templates/:id
      def update
        return not_found unless @template

        attrs = template_params.to_h.symbolize_keys
        attrs[:note] = attrs.delete(:description) if attrs.key?(:description)
        attrs[:recurrence_days] = Array(attrs[:recurrence_days]).map(&:to_i) if attrs.key?(:recurrence_days)

        if @template.update(attrs)
          # Propagate only fields that were provided, to FUTURE, INCOMPLETE instances
          changed_fields = {}
          changed_fields[:title] = @template.title if attrs.key?(:title)
          changed_fields[:note]  = @template.note  if attrs.key?(:note)

          if changed_fields.present?
            Task.where(recurring_template_id: @template.id)
                .where("due_at > ?", Time.current)
                .where.not(status: Task.statuses[:done])
                .find_each { |inst| inst.update!(changed_fields) }
          end

          render json: serialize_template(@template), status: :ok
        else
          validation_error!(@template)
        end
      end

      # DELETE /api/v1/recurring_templates/:id
      def destroy
        return not_found unless @template

        if ActiveModel::Type::Boolean.new.cast(params[:delete_instances])
          Task.where(recurring_template_id: @template.id).find_each(&:destroy!)
        end
        @template.destroy!
        head :no_content
      end

      # POST /api/v1/recurring_templates/:id/generate_instance
      def generate_instance
        return not_found unless @template
        instance = @template.generate_next_instance
        return render_error("Could not generate instance", :unprocessable_entity) unless instance
        render json: serialize_instance(instance), status: :created
      end

      # GET /api/v1/recurring_templates/:id/instances
      def instances
        return not_found unless @template
        instances = Task.where(recurring_template_id: @template.id).order(due_at: :desc)   # spec expects ordering by due_at descending
        render json: instances.map { |i| serialize_instance(i) }, status: :ok
      end

      private

      def require_auth!
        return if current_user.present?
        render json: { error: { message: "Unauthorized" } }, status: :unauthorized
      end

      # 🔽 IMPORTANT: specs create lists with lists.user_id, not owner_id
      def base_scope
        Task
          .joins(:list)
          .where(lists: { user_id: current_user.id })
          .where(is_recurring: true, recurring_template_id: nil)
      end

      def set_template
        @template = base_scope.find_by(id: params[:id])
      end

      def not_found
        render_error("Recurring template not found", :not_found)
      end

      def render_error(message, status)
        render json: { error: { message: message } }, status: status
      end

      def validation_error!(record)
        render json: {
          error: {
            message: "Validation failed",
            details: record.errors.as_json
          }
        }, status: :unprocessable_entity
      end

      # Specs pass flat params (no wrapper)
      def template_params
        # Handle both flat params and nested recurring_template params
        if params[:recurring_template].present?
          params.require(:recurring_template).permit(
            :title, :note, :description,
            :visibility,
            :strict_mode, :can_be_snoozed, :notification_interval_minutes,
            :requires_explanation_if_missed,
            :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
            :location_based, :location_latitude, :location_longitude, :location_radius_meters,
            :location_name, :notify_on_arrival, :notify_on_departure,
            recurrence_days: []
          )
        else
          params.permit(
            :list_id,
            :title, :note, :description,
            :visibility,
            :strict_mode, :can_be_snoozed, :notification_interval_minutes,
            :requires_explanation_if_missed,
            :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
            :location_based, :location_latitude, :location_longitude, :location_radius_meters,
            :location_name, :notify_on_arrival, :notify_on_departure,
            recurrence_days: []
          )
        end
      end

      def serialize_template(t, include_instances: false)
        payload = {
          id: t.id,
          list_id: t.list_id,
          title: t.title,
          note: t.note,
          is_recurring: t.is_recurring?,
          recurrence_pattern: t.recurrence_pattern,
          recurrence_interval: t.recurrence_interval,
          recurrence_days: t.recurrence_days,
          recurrence_time: t.recurrence_time&.strftime("%H:%M"),
          recurrence_end_date: t.recurrence_end_date,
          visibility: t.visibility,
          created_at: t.created_at,
          updated_at: t.updated_at
        }
        if include_instances
          payload[:instances] = Task.where(recurring_template_id: t.id).order(:due_at).map { |i| serialize_instance(i) }
        end
        payload
      end

      def serialize_instance(i)
        {
          id: i.id,
          title: i.title,
          note: i.note,
          list_id: i.list_id,
          due_at: i.due_at,
          status: i.status,
          recurring_template_id: i.recurring_template_id,
          created_at: i.created_at,
          updated_at: i.updated_at
        }
      end
    end
  end
end
