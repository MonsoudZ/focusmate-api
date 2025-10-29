module Api
  module V1
    class RecurringTemplatesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_template, only: [ :show, :update, :destroy, :generate_instance, :instances ]
      before_action :validate_params, only: [ :create, :update ]

      # GET /api/v1/recurring_templates
      def index
        begin
          templates = build_templates_query
          render json: templates.map { |t| serialize_template(t) }, status: :ok
        rescue => e
          Rails.logger.error "RecurringTemplatesController#index error: #{e.message}"
          render json: { error: { message: "Failed to retrieve recurring templates" } },
                 status: :internal_server_error
        end
      end

      # GET /api/v1/recurring_templates/:id
      def show
        begin
          return not_found unless @template
          render json: serialize_template(@template, include_instances: true), status: :ok
        rescue => e
          Rails.logger.error "RecurringTemplatesController#show error: #{e.message}"
          render json: { error: { message: "Failed to retrieve recurring template" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/recurring_templates
      def create
        begin
          list = find_authorized_list(params[:list_id])
          return if performed? # Early return if error was rendered

          attrs = prepare_template_attributes(template_params.to_h.symbolize_keys)
          return if performed? # Early return if error was rendered

          template = list.tasks.new(attrs.merge(creator: current_user))

          if template.save
            render json: serialize_template(template), status: :created
          else
            Rails.logger.error "Template validation failed: #{template.errors.full_messages}"
            render json: {
              error: {
                message: "Validation failed",
                details: template.errors.as_json
              }
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "RecurringTemplatesController#create error: #{e.message}"
          render json: { error: { message: "Failed to create recurring template" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/recurring_templates/:id
      def update
        begin
          return not_found unless @template

          attrs = prepare_template_attributes(template_params.to_h.symbolize_keys)
          return if performed? # Early return if error was rendered

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
            Rails.logger.error "Template update validation failed: #{@template.errors.full_messages}"
            render json: {
              error: {
                message: "Validation failed",
                details: @template.errors.as_json
              }
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "RecurringTemplatesController#update error: #{e.message}"
          render json: { error: { message: "Failed to update recurring template" } },
                 status: :internal_server_error
        end
      end

      # DELETE /api/v1/recurring_templates/:id
      def destroy
        begin
          return not_found unless @template

          if ActiveModel::Type::Boolean.new.cast(params[:delete_instances])
            Task.where(recurring_template_id: @template.id).find_each(&:destroy!)
          end
          @template.destroy!
          head :no_content
        rescue => e
          Rails.logger.error "RecurringTemplatesController#destroy error: #{e.message}"
          render json: { error: { message: "Failed to delete recurring template" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/recurring_templates/:id/generate_instance
      def generate_instance
        begin
          return not_found unless @template
          instance = @template.generate_next_instance
          unless instance
            render json: { error: { message: "Could not generate instance" } },
                   status: :unprocessable_entity
            return
          end
          render json: serialize_instance(instance), status: :created
        rescue => e
          Rails.logger.error "RecurringTemplatesController#generate_instance error: #{e.message}"
          render json: { error: { message: "Failed to generate instance" } },
                 status: :internal_server_error
        end
      end

      # GET /api/v1/recurring_templates/:id/instances
      def instances
        begin
          return not_found unless @template
          instances = Task.where(recurring_template_id: @template.id).order(due_at: :desc)   # spec expects ordering by due_at descending
          render json: instances.map { |i| serialize_instance(i) }, status: :ok
        rescue => e
          Rails.logger.error "RecurringTemplatesController#instances error: #{e.message}"
          render json: { error: { message: "Failed to retrieve instances" } },
                 status: :internal_server_error
        end
      end

      private

      def build_templates_query
        templates = base_scope
        templates = templates.where(list_id: params[:list_id]) if params[:list_id].present?
        templates
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
        render json: { error: { message: "Recurring template not found" } }, status: :not_found
      end

      def find_authorized_list(list_id)
        return nil if list_id.blank?

        list = current_user&.owned_lists&.find_by(id: list_id) ||
               List.find_by(id: list_id, user_id: current_user.id)

        unless list
          render json: { error: { message: "List not found" } }, status: :not_found
          return nil
        end

        list
      end

      def prepare_template_attributes(attrs)
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

        attrs
      end

      def validate_params
        # Validate recurrence_time format if present
        if params[:recurrence_time].present?
          time_str = params[:recurrence_time].to_s
          unless time_str.match?(/\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/)
            render json: {
              error: {
                message: "Validation failed",
                details: { recurrence_time: [ "must be in HH:MM format" ] }
              }
            }, status: :unprocessable_entity
            return
          end
        end

        # Validate recurrence_days if present
        if params[:recurrence_days].present?
          days = Array(params[:recurrence_days])
          valid_days = (0..6).to_a
          day_map = { "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3, "thursday" => 4, "friday" => 5, "saturday" => 6 }

          days.each do |day|
            day_value = day_map[day.to_s.downcase] || day.to_i
            unless valid_days.include?(day_value)
              render json: {
                error: {
                  message: "Validation failed",
                  details: { recurrence_days: [ "must be valid day values (0-6 or day names)" ] }
                }
              }, status: :unprocessable_entity
              return
            end
          end
        end

        # Validate list_id if present
        if params[:list_id].present?
          unless params[:list_id].to_s.match?(/\A\d+\z/)
            render json: {
              error: {
                message: "Validation failed",
                details: { list_id: [ "must be a valid integer" ] }
              }
            }, status: :unprocessable_entity
            nil
          end
        end
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
