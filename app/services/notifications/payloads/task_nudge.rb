# frozen_string_literal: true

module Notifications
  module Payloads
    class TaskNudge
      def self.build(task:, reason:, options:)
        title, body = title_and_body(task:, reason:)

        {
          aps: {
            alert: { title: title, body: body },
            sound: "default"
          },
          data: {
            type: "task.nudge",
            task_id: task.id,
            list_id: task.list_id,
            priority: (options[:priority].presence || "normal"),
            timestamp: Time.current.to_i,
            title: title,
            body: body
          }
        }
      end

      def self.title_and_body(task:, reason:)
        task_title = truncate(task.title.to_s, 50)

        if task.respond_to?(:done?) && task.done?
          ["Task Completed", "Completed: #{task_title}"]
        elsif reason.present?
          r = truncate(reason.to_s, 100)
          ["Task Reassigned", "Reassigned: #{task_title} — #{r}"]
        else
          ["Task Reminder", "Due soon: #{task_title}"]
        end
      end

      def self.truncate(text, max)
        return text if text.length <= max
        text[0, max - 3] + "..."
      end

      private_class_method :truncate, :title_and_body
    end
  end
end
