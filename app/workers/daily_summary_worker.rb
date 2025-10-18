class DailySummaryWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform
    current_hour = Time.current.hour
    Rails.logger.info "[DailySummaryWorker] Checking for summaries to send at hour #{current_hour}"

    # Find relationships that want daily summaries at this hour
    CoachingRelationship.active
                        .where(send_daily_summary: true)
                        .where.not(daily_summary_time: nil)
                        .find_each do |relationship|
      summary_hour = relationship.daily_summary_time.hour

      # Check if it's time to send (within this hour)
      if current_hour == summary_hour
        process_daily_summary(relationship)
      end
    end

    Rails.logger.info "[DailySummaryWorker] Completed daily summary check"
  end

  private

  def process_daily_summary(relationship)
    today = Date.current

    # Check if already sent today
    existing_summary = relationship.daily_summaries.find_by(summary_date: today)

    if existing_summary&.sent?
      Rails.logger.info "[DailySummaryWorker] Summary already sent for relationship ##{relationship.id} on #{today}"
      return
    end

    Rails.logger.info "[DailySummaryWorker] Generating summary for relationship ##{relationship.id}"

    begin
      relationship.generate_daily_summary!(today)
      Rails.logger.info "[DailySummaryWorker] Successfully sent summary for relationship ##{relationship.id}"
    rescue => e
      Rails.logger.error "[DailySummaryWorker] Error generating summary for relationship ##{relationship.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
