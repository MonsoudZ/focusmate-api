class OverdueScanJob
  include Sidekiq::Job

  def perform
    Task.where(status: "pending").where("due_at < ?", 10.minutes.ago).find_each do |task|
      NudgeJob.perform_async(task.id)
    end
  end
end
