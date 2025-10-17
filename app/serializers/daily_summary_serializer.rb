class DailySummarySerializer
  attr_reader :summary, :options

  def initialize(summary, **options)
    @summary = summary
    @options = options
  end

  def as_json
    {
      id: summary.id,
      summary_date: summary.summary_date.iso8601,
      tasks_completed: summary.tasks_completed,
      tasks_missed: summary.tasks_missed,
      tasks_overdue: summary.tasks_overdue,
      completion_rate: summary.completion_rate,
      sent: summary.sent,
      sent_at: summary.sent_at&.iso8601
    }.tap do |hash|
      if options[:detailed]
        hash[:summary_data] = summary.summary_data
      end
    end
  end
end
