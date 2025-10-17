class RecurringTemplateSerializer
  attr_reader :template, :options

  def initialize(template, **options)
    @template = template
    @options = options
  end

  def as_json
    {
      id: template.id,
      title: template.title,
      description: template.description,
      recurrence_pattern: template.recurrence_pattern,
      recurrence_interval: template.recurrence_interval,
      recurrence_days: template.recurrence_days,
      recurrence_time: template.recurrence_time&.strftime('%H:%M'),
      recurrence_end_date: template.recurrence_end_date&.iso8601,
      priority: template.priority,
      list: {
        id: template.list.id,
        name: template.list.name
      },
      instances_count: template.recurring_instances.count,
      active_instances_count: template.recurring_instances.incomplete.count,
      next_due_at: template.calculate_next_due_date&.iso8601,
      created_at: template.created_at.iso8601
    }.tap do |hash|
      if options[:include_instances]
        hash[:instances] = template.recurring_instances.order(due_at: :desc).limit(20).map do |instance|
          {
            id: instance.id,
            due_at: instance.due_at.iso8601,
            completed_at: instance.completed_at&.iso8601
          }
        end
      end
    end
  end
end
