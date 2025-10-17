module Broadcasts
  module_function

  def task_changed(task, event:)
    ListChannel.broadcast_to(
      task.list,
      {
        type: "task.#{event}",
        task: {
          id: task.id,
          title: task.title,
          note: task.note,
          due_at: task.due_at,
          status: task.status,
          strict_mode: task.strict_mode,
          updated_at: task.updated_at
        }
      }
    )
  end
end
