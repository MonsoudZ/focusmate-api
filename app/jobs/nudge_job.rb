class NudgeJob
  include Sidekiq::Job

  def perform(task_id, reason = nil)
    task = Task.find(task_id)
    list = task.list
    members = list.memberships.includes(:user).map(&:user)

    members.each do |user|
      user.devices.find_each do |device|
        ApnsClient.new.push(
          device_token: device.apns_token,
          title: "Task updated",
          body:  push_body(task, reason),
          payload: { type: "task.nudge", task_id: task.id }
        )
      end
    end
  end

  private

  def push_body(task, reason)
    if task.done?
      "Completed: #{task.title}"
    elsif reason.present?
      "Reassigned: #{task.title} — #{reason}"
    else
      "Due soon: #{task.title}"
    end
  end
end
